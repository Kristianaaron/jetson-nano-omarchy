import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name('ioctl_table.py')


class IoctlTableTest(unittest.TestCase):
    def test_multiline_and_simple_ioctl_definitions(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            header = root / 'nvgpu-test.h'
            header.write_text("""#define NVGPU_IOCTL_MAGIC 'H'
#define NVGPU_IOCTL_FOO \\
    _IOWR(NVGPU_IOCTL_MAGIC, 7, struct nvgpu_foo_args)
#define NVGPU_IOCTL_BAR _IO(NVGPU_IOCTL_MAGIC, 8)
""")
            output = root / 'ioctls.json'
            subprocess.run([sys.executable, str(SCRIPT), '--label', 'fixture', '--out', str(output), str(root)], check=True)
            entries = {entry['name']: entry for entry in json.loads(output.read_text())}
            self.assertEqual(entries['NVGPU_IOCTL_FOO']['dir'], 'rw')
            self.assertEqual(entries['NVGPU_IOCTL_FOO']['magic'], 72)
            self.assertEqual(entries['NVGPU_IOCTL_FOO']['nr'], 7)
            self.assertEqual(entries['NVGPU_IOCTL_FOO']['type'], 'nvgpu_foo_args')
            self.assertEqual(entries['NVGPU_IOCTL_BAR']['dir'], 'none')
            self.assertEqual(entries['NVGPU_IOCTL_BAR']['nr'], 8)


if __name__ == '__main__':
    unittest.main()
