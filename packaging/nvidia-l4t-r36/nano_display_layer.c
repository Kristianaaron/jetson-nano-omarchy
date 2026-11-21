// SPDX-License-Identifier: MIT
/*
 * VK_LAYER_NANO_display: make NVIDIA's L4T R36 Vulkan driver report what it can do on mainline
 * Linux, where tegra-drm drives the display instead of NVIDIA's downstream display stack.
 *
 * 1. Displays.
 *
 * The R36 driver implements VK_KHR_display through libnvdc, which opens the downstream display
 * controller /dev/tegra_dc_ctrl. Mainline drives the display with tegra-drm, so the open fails
 * and the display queries return VK_ERROR_INITIALIZATION_FAILED, which the Vulkan spec does not
 * allow for them (only VK_SUCCESS, VK_INCOMPLETE and out-of-memory). vulkaninfo aborts on it.
 * A GPU with no displays reachable through Vulkan must report zero of them, so this layer turns
 * exactly that result into VK_SUCCESS with a count of 0.
 *
 * 2. Window surfaces. The driver advertises VK_KHR_wayland_surface, VK_KHR_xcb_surface and
 * VK_KHR_xlib_surface, but its presentation path needs NVIDIA's own display driver: on mainline,
 * presenting to a Wayland or X window hangs (vkcube, mpv's Vulkan output, GTK 4's Vulkan
 * renderer). This layer removes those extensions from the instance extension list and refuses
 * them at vkCreateInstance with VK_ERROR_EXTENSION_NOT_PRESENT, as for any unsupported
 * extension, so applications choose their OpenGL path (Mesa Zink on this same GPU). Vulkan
 * compute, offscreen rendering and Zink, which presents through dma-buf, are unaffected.
 *
 * 3. Driver lifetime. When its last instance or device goes away, the driver dlcloses its core
 * libraries (libnvidia-eglcore, libnvdc, libnvimp, ...) while worker threads it started are
 * still waiting in them; a thread that wakes before the process exits jumps into unmapped code
 * (SIGSEGV at exit in 2 of 5 runs of a GL app on Zink). Once the driver is loaded, this layer
 * marks its libraries RTLD_NODELETE, so they stay mapped until the process ends.
 *
 * Every other call and result passes through unchanged. DISABLE_VK_LAYER_NANO_display=1 turns
 * the layer off (for example to test a window-system layer that provides real presentation).
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <link.h>
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

static const char *const hidden_extensions[] = {
	"VK_KHR_wayland_surface",
	"VK_KHR_xcb_surface",
	"VK_KHR_xlib_surface",
};

static int hidden(const char *name)
{
	for (size_t n = 0; n < sizeof(hidden_extensions) / sizeof(hidden_extensions[0]); n++)
		if (!strcmp(name, hidden_extensions[n]))
			return 1;
	return 0;
}

/* Pin every loaded library of the L4T driver (RTLD_NODELETE): see 3. above. The names are
 * collected first and dlopen()ed after dl_iterate_phdr() returns, outside the loader lock. */
#define L4T_DIR "/nvidia-l4t/"

struct pin_list {
	char *name[64];
	int n;
};

static int collect_l4t(struct dl_phdr_info *info, size_t size, void *data)
{
	struct pin_list *l = data;

	(void)size;
	if (info->dlpi_name && strstr(info->dlpi_name, L4T_DIR) && l->n < 64)
		l->name[l->n++] = strdup(info->dlpi_name);
	return 0;
}

static void pin_driver(void)
{
	struct pin_list l = { .n = 0 };

	dl_iterate_phdr(collect_l4t, &l);
	for (int k = 0; k < l.n; k++) {
		if (l.name[k])
			dlopen(l.name[k], RTLD_NOW | RTLD_NOLOAD | RTLD_NODELETE);
		free(l.name[k]);
	}
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

	for (uint32_t n = 0; n < info->enabledExtensionCount; n++)
		if (hidden(info->ppEnabledExtensionNames[n]))
			return VK_ERROR_EXTENSION_NOT_PRESENT;

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
	pin_driver();
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
	pin_driver();
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

/* Pre-instance hook (manifest "pre_instance_functions"): the instance extension list without the
 * window-surface extensions the driver cannot present to. */
EXPORT VKAPI_ATTR VkResult VKAPI_CALL
nano_EnumerateInstanceExtensionProperties(const VkEnumerateInstanceExtensionPropertiesChain *chain,
					  const char *layer, uint32_t *count,
					  VkExtensionProperties *props)
{
	uint32_t all = 0, kept = 0;
	VkExtensionProperties *list;
	VkResult r;

	if (layer)
		return chain->pfnNextLayer(chain->pNextLink, layer, count, props);
	r = chain->pfnNextLayer(chain->pNextLink, NULL, &all, NULL);
	if (r != VK_SUCCESS)
		return r;
	list = calloc(all ? all : 1, sizeof(*list));
	if (!list)
		return VK_ERROR_OUT_OF_HOST_MEMORY;
	r = chain->pfnNextLayer(chain->pNextLink, NULL, &all, list);
	if (r != VK_SUCCESS && r != VK_INCOMPLETE) {
		free(list);
		return r;
	}
	for (uint32_t n = 0; n < all; n++)
		if (!hidden(list[n].extensionName))
			list[kept++] = list[n];
	if (!props) {
		*count = kept;
		free(list);
		return VK_SUCCESS;
	}
	r = *count < kept ? VK_INCOMPLETE : VK_SUCCESS;
	if (*count > kept)
		*count = kept;
	memcpy(props, list, *count * sizeof(*props));
	free(list);
	return r;
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
