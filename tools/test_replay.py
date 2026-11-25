"""Exercise actual replay binaries against isolated input roots."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SHOWCASE, FAILURE = [str(Path(value).resolve()) for value in sys.argv[1:3]]
del sys.argv[1:3]


class ReplayTests(unittest.TestCase):
    def run_example(self, binary, package, events):
        with tempfile.TemporaryDirectory(dir='.work') as directory:
            root = Path(directory)
            path = root / 'examples' / package / 'events.json'
            path.parent.mkdir(parents=True)
            path.write_text(events if isinstance(events, str) else json.dumps(events))
            result = subprocess.run([binary], cwd=root, text=True, capture_output=True, timeout=2)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout

    def test_unicode_editing_and_whole_edit_capacity_rejection(self):
        events = [{'viewport': [800, 600], 'keys_pressed': ['TAB']},
                  {'viewport': [800, 600], 'keys_pressed': ['TAB']},
                  {'viewport': [800, 600], 'keys_down': ['LEFT_CONTROL'],
                   'keys_pressed': ['A'], 'text': 'é🙂'},
                  {'viewport': [800, 600], 'text': 'x' * 257}]
        output = self.run_example(SHOWCASE, 'showcase', events)
        self.assertIn('frames=4', output)
        self.assertIn('name="é🙂"', output)

    def test_focus_cancels_capture_and_touch_replacement_is_replayable(self):
        events = [{'viewport': [800, 600]},
                  {'viewport': [800, 600], 'touches': [{'id': 7, 'position': {'x': 100, 'y': 140}}]},
                  {'viewport': [800, 600], 'blur': True},
                  {'viewport': [800, 600], 'touches': [{'id': 9, 'position': {'x': 100, 'y': 140}}]},
                  {'viewport': [0, 0]}, {'viewport': [800, 600]}]
        self.assertIn('frames=6 clicks=0', self.run_example(SHOWCASE, 'showcase', events))

    def test_invalid_and_closed_input_is_not_an_assertion(self):
        for events in ['{', [{'viewport': [-1, 10]}], [{'dt': -1}],
                       [{'touches': [{'id': -1}]}]]:
            self.assertEqual(self.run_example(SHOWCASE, 'showcase', events), '')
        output = self.run_example(SHOWCASE, 'showcase', [{'close': True}, {'viewport': [800, 600]}])
        self.assertIn('frames=0', output)

    def test_zero_width_presentation_has_no_hit_or_capture(self):
        # Reduced from the first confirmed campaign finding: missing width is zero.
        self.assertEqual(self.run_example(FAILURE, 'failure_policy', [{}]), 'fresh Revision 0\n')

    def test_failure_retention_invalidation_and_recovery(self):
        output = self.run_example(FAILURE, 'failure_policy', [
            {'revision': 0, 'width': 320}, {'revision': 0, 'width': 320, 'fail': True},
            {'revision': 1, 'width': 320, 'fail': True}, {'revision': 1, 'width': 640}])
        self.assertEqual(output.splitlines(), [
            'fresh Revision 0', 'retained Revision 0',
            'Unable to display UI. Ordinary actions are disabled.', 'fresh Revision 1'])


if __name__ == '__main__':
    unittest.main()
