// SPDX-License-Identifier: MIT
/*
 * VK_LAYER_NANO_display: report "no displays" instead of an invalid error from NVIDIA's L4T R36
 * Vulkan driver on mainline Linux.
 *
 * The R36 driver implements VK_KHR_display through libnvdc, which opens the downstream display
 * controller /dev/tegra_dc_ctrl. Mainline drives the display with tegra-drm, so the open fails
 * and the display queries return VK_ERROR_INITIALIZATION_FAILED, which the Vulkan spec does not
 * allow for them (only VK_SUCCESS, VK_INCOMPLETE and out-of-memory). vulkaninfo aborts on it.
 * A GPU with no displays reachable through Vulkan must report zero of them, so this layer turns
 * exactly that result into VK_SUCCESS with a count of 0. Every other call and result passes
 * through unchanged.
 */
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <vulkan/vulkan.h>
#include <vulkan/vk_layer.h>

#define EXPORT __attribute__((visibility("default")))

struct instance {
	VkInstance handle;
	PFN_vkGetInstanceProcAddr gipa;
	struct instance *next;
};

struct device {
	VkDevice handle;
	PFN_vkGetDeviceProcAddr gdpa;
	struct device *next;
};

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
static struct instance *instances;
static struct device *devices;

/* Dispatchable handles start with the loader's dispatch table pointer. */
static void *dispatch_key(const void *handle)
{
	return *(void **)handle;
}

static PFN_vkGetInstanceProcAddr instance_gipa(const void *handle)
{
	PFN_vkGetInstanceProcAddr gipa = NULL;

	pthread_mutex_lock(&lock);
	for (struct instance *i = instances; i; i = i->next)
		if (dispatch_key(i->handle) == dispatch_key(handle))
			gipa = i->gipa;
	pthread_mutex_unlock(&lock);
	return gipa;
}

/* Physical devices share their instance's dispatch table. */
#define NEXT(fn, handle) ((PFN_##fn)instance_gipa(handle)(instance_of(handle), #fn))

static VkInstance instance_of(const void *handle)
{
	VkInstance found = VK_NULL_HANDLE;

	pthread_mutex_lock(&lock);
	for (struct instance *i = instances; i; i = i->next)
		if (dispatch_key(i->handle) == dispatch_key(handle))
			found = i->handle;
	pthread_mutex_unlock(&lock);
	return found;
}

static VkResult no_display(VkResult r, uint32_t *count)
{
	if (r != VK_ERROR_INITIALIZATION_FAILED)
		return r;
	*count = 0;
	return VK_SUCCESS;
}

static VKAPI_ATTR VkResult VKAPI_CALL
display_props(VkPhysicalDevice pd, uint32_t *count, VkDisplayPropertiesKHR *props)
{
	return no_display(NEXT(vkGetPhysicalDeviceDisplayPropertiesKHR, pd)(pd, count, props), count);
}

static VKAPI_ATTR VkResult VKAPI_CALL
display_props2(VkPhysicalDevice pd, uint32_t *count, VkDisplayProperties2KHR *props)
{
	return no_display(NEXT(vkGetPhysicalDeviceDisplayProperties2KHR, pd)(pd, count, props), count);
}

static VKAPI_ATTR VkResult VKAPI_CALL
plane_props(VkPhysicalDevice pd, uint32_t *count, VkDisplayPlanePropertiesKHR *props)
{
	return no_display(NEXT(vkGetPhysicalDeviceDisplayPlanePropertiesKHR, pd)(pd, count, props),
			  count);
}

static VKAPI_ATTR VkResult VKAPI_CALL
plane_props2(VkPhysicalDevice pd, uint32_t *count, VkDisplayPlaneProperties2KHR *props)
{
	return no_display(NEXT(vkGetPhysicalDeviceDisplayPlaneProperties2KHR, pd)(pd, count, props),
			  count);
}

static VKAPI_ATTR VkResult VKAPI_CALL
create_instance(const VkInstanceCreateInfo *info, const VkAllocationCallbacks *alloc,
		VkInstance *out)
{
	VkLayerInstanceCreateInfo *chain = (VkLayerInstanceCreateInfo *)info->pNext;

	while (chain && !(chain->sType == VK_STRUCTURE_TYPE_LOADER_INSTANCE_CREATE_INFO &&
			  chain->function == VK_LAYER_LINK_INFO))
		chain = (VkLayerInstanceCreateInfo *)chain->pNext;
	if (!chain)
		return VK_ERROR_INITIALIZATION_FAILED;

	PFN_vkGetInstanceProcAddr gipa = chain->u.pLayerInfo->pfnNextGetInstanceProcAddr;
	PFN_vkCreateInstance next = (PFN_vkCreateInstance)gipa(VK_NULL_HANDLE, "vkCreateInstance");
	struct instance *i = calloc(1, sizeof(*i));

	if (!next || !i) {
		free(i);
		return VK_ERROR_INITIALIZATION_FAILED;
	}
	chain->u.pLayerInfo = chain->u.pLayerInfo->pNext;

	VkResult r = next(info, alloc, out);
	if (r != VK_SUCCESS) {
		free(i);
		return r;
	}
	i->handle = *out;
	i->gipa = gipa;
	pthread_mutex_lock(&lock);
	i->next = instances;
	instances = i;
	pthread_mutex_unlock(&lock);
	return VK_SUCCESS;
}

static VKAPI_ATTR void VKAPI_CALL
destroy_instance(VkInstance instance, const VkAllocationCallbacks *alloc)
{
	PFN_vkDestroyInstance next = NEXT(vkDestroyInstance, instance);
	struct instance *gone = NULL;

	pthread_mutex_lock(&lock);
	for (struct instance **p = &instances; *p; p = &(*p)->next)
		if ((*p)->handle == instance) {
			gone = *p;
			*p = gone->next;
			break;
		}
	pthread_mutex_unlock(&lock);
	next(instance, alloc);
	free(gone);
}

static PFN_vkGetDeviceProcAddr device_gdpa(VkDevice device)
{
	PFN_vkGetDeviceProcAddr gdpa = NULL;

	pthread_mutex_lock(&lock);
	for (struct device *d = devices; d; d = d->next)
		if (dispatch_key(d->handle) == dispatch_key(device))
			gdpa = d->gdpa;
	pthread_mutex_unlock(&lock);
	return gdpa;
}

static VKAPI_ATTR VkResult VKAPI_CALL
create_device(VkPhysicalDevice pd, const VkDeviceCreateInfo *info,
	      const VkAllocationCallbacks *alloc, VkDevice *out)
{
	VkLayerDeviceCreateInfo *chain = (VkLayerDeviceCreateInfo *)info->pNext;

	while (chain && !(chain->sType == VK_STRUCTURE_TYPE_LOADER_DEVICE_CREATE_INFO &&
			  chain->function == VK_LAYER_LINK_INFO))
		chain = (VkLayerDeviceCreateInfo *)chain->pNext;
	if (!chain)
		return VK_ERROR_INITIALIZATION_FAILED;

	PFN_vkGetInstanceProcAddr gipa = chain->u.pLayerInfo->pfnNextGetInstanceProcAddr;
	PFN_vkGetDeviceProcAddr gdpa = chain->u.pLayerInfo->pfnNextGetDeviceProcAddr;
	PFN_vkCreateDevice next = (PFN_vkCreateDevice)gipa(instance_of(pd), "vkCreateDevice");
	struct device *d = calloc(1, sizeof(*d));

	if (!next || !d) {
		free(d);
		return VK_ERROR_INITIALIZATION_FAILED;
	}
	chain->u.pLayerInfo = chain->u.pLayerInfo->pNext;

	VkResult r = next(pd, info, alloc, out);
	if (r != VK_SUCCESS) {
		free(d);
		return r;
	}
	d->handle = *out;
	d->gdpa = gdpa;
	pthread_mutex_lock(&lock);
	d->next = devices;
	devices = d;
	pthread_mutex_unlock(&lock);
	return VK_SUCCESS;
}

static VKAPI_ATTR void VKAPI_CALL
destroy_device(VkDevice device, const VkAllocationCallbacks *alloc)
{
	PFN_vkDestroyDevice next = (PFN_vkDestroyDevice)device_gdpa(device)(device, "vkDestroyDevice");
	struct device *gone = NULL;

	pthread_mutex_lock(&lock);
	for (struct device **p = &devices; *p; p = &(*p)->next)
		if ((*p)->handle == device) {
			gone = *p;
			*p = gone->next;
			break;
		}
	pthread_mutex_unlock(&lock);
	next(device, alloc);
	free(gone);
}

EXPORT VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL
nano_GetDeviceProcAddr(VkDevice device, const char *name)
{
	if (!strcmp(name, "vkGetDeviceProcAddr"))
		return (PFN_vkVoidFunction)nano_GetDeviceProcAddr;
	if (!strcmp(name, "vkDestroyDevice"))
		return (PFN_vkVoidFunction)destroy_device;
	return device_gdpa(device)(device, name);
}

EXPORT VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL
nano_GetInstanceProcAddr(VkInstance instance, const char *name)
{
	static const struct {
		const char *name;
		PFN_vkVoidFunction fn;
	} hooks[] = {
		{ "vkGetInstanceProcAddr", (PFN_vkVoidFunction)nano_GetInstanceProcAddr },
		{ "vkGetDeviceProcAddr", (PFN_vkVoidFunction)nano_GetDeviceProcAddr },
		{ "vkCreateInstance", (PFN_vkVoidFunction)create_instance },
		{ "vkDestroyInstance", (PFN_vkVoidFunction)destroy_instance },
		{ "vkCreateDevice", (PFN_vkVoidFunction)create_device },
		{ "vkGetPhysicalDeviceDisplayPropertiesKHR", (PFN_vkVoidFunction)display_props },
		{ "vkGetPhysicalDeviceDisplayProperties2KHR", (PFN_vkVoidFunction)display_props2 },
		{ "vkGetPhysicalDeviceDisplayPlanePropertiesKHR", (PFN_vkVoidFunction)plane_props },
		{ "vkGetPhysicalDeviceDisplayPlaneProperties2KHR", (PFN_vkVoidFunction)plane_props2 },
	};

	for (size_t n = 0; n < sizeof(hooks) / sizeof(hooks[0]); n++)
		if (!strcmp(name, hooks[n].name))
			return hooks[n].fn;
	if (instance == VK_NULL_HANDLE)
		return NULL;
	return instance_gipa(instance)(instance, name);
}

EXPORT VKAPI_ATTR VkResult VKAPI_CALL
nano_NegotiateLoaderLayerInterfaceVersion(VkNegotiateLayerInterface *v)
{
	if (v->loaderLayerInterfaceVersion > 2)
		v->loaderLayerInterfaceVersion = 2;
	v->pfnGetInstanceProcAddr = nano_GetInstanceProcAddr;
	v->pfnGetDeviceProcAddr = nano_GetDeviceProcAddr;
	v->pfnGetPhysicalDeviceProcAddr = NULL;
	return VK_SUCCESS;
}
