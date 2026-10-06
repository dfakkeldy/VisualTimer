"""Regression checks for the iOS app's paired Watch product packaging."""
import json
import re
from pathlib import Path
import subprocess
import unittest

PROJECT = Path(__file__).resolve().parents[3] / 'Visual Timer.xcodeproj/project.pbxproj'

class WatchPackagingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        project = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(PROJECT)]))
        cls.objects = project['objects']
        targets = {key: value for key, value in cls.objects.items() if value.get('isa') == 'PBXNativeTarget'}
        cls.phone_id, cls.phone = next((key, value) for key, value in targets.items() if value['name'] == 'Visual Timer')
        cls.watch_id, cls.watch = next((key, value) for key, value in targets.items() if value.get('productType') == 'com.apple.product-type.application' and any(cls.objects[c]['buildSettings'].get('SDKROOT') == 'watchos' for c in cls.objects[value['buildConfigurationList']]['buildConfigurations']))

    def configurations(self, target):
        return {self.objects[key]['name']: self.objects[key]['buildSettings'] for key in self.objects[target['buildConfigurationList']]['buildConfigurations']}

    def test_iphone_embeds_the_actual_watch_application(self):
        phases = [self.objects[key] for key in self.phone['buildPhases']]
        embedded = [self.objects[file]['fileRef'] for phase in phases if phase.get('isa') == 'PBXCopyFilesBuildPhase' and phase.get('dstSubfolderSpec') == '16' for file in phase.get('files', [])]
        self.assertIn(self.watch['productReference'], embedded, 'The iOS product must contain the actual Watch app, rather than merely building a separate Watch container.')

    def test_iphone_builds_watch_dependency(self):
        pending = [self.phone_id]
        seen = set()
        while pending:
            current = pending.pop()
            if current in seen:
                continue
            seen.add(current)
            pending.extend(self.objects[key]['target'] for key in self.objects[current].get('dependencies', []))
        self.assertIn(self.watch_id, seen, 'An iOS archive must build its embedded Watch product.')

    def test_watch_bundle_identifier_belongs_to_iphone(self):
        phone_configs = self.configurations(self.phone)
        for name, settings in self.configurations(self.watch).items():
            with self.subTest(configuration=name):
                self.assertTrue(settings['PRODUCT_BUNDLE_IDENTIFIER'].startswith(
                    phone_configs[name]['PRODUCT_BUNDLE_IDENTIFIER'] + '.'
                ), 'The paired Watch identifier must begin with the iPhone identifier and a dot.')

    def test_release_signing_maps_actual_watch_identifier(self):
        repo = PROJECT.parent.parent
        fastfile = (repo / 'fastlane/Fastfile').read_text()
        matchfile = (repo / 'fastlane/Matchfile').read_text()
        mapped = re.search(r'"' + re.escape(self.watch['name']) + r'"\s*=>\s*"([^"]+)"', fastfile)
        self.assertIsNotNone(mapped)
        for name, settings in self.configurations(self.watch).items():
            with self.subTest(configuration=name):
                identifier = settings['PRODUCT_BUNDLE_IDENTIFIER']
                self.assertEqual(mapped.group(1), identifier)
                self.assertIn('"' + identifier + '"', matchfile)

    def test_watch_declares_iphone_companion(self):
        phone_configs = self.configurations(self.phone)
        for name, settings in self.configurations(self.watch).items():
            with self.subTest(configuration=name):
                self.assertNotEqual(settings.get('INFOPLIST_KEY_WKWatchOnly'), 'YES', 'A companion Watch app cannot declare itself Watch-only.')
                self.assertEqual(settings.get('INFOPLIST_KEY_WKCompanionAppBundleIdentifier'), phone_configs[name]['PRODUCT_BUNDLE_IDENTIFIER'])

if __name__ == '__main__':
    unittest.main()
