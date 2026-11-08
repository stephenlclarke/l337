"""Source geometry checks for the actual SH040 cryostasis asset."""
from collections import Counter
from pathlib import Path
import tomllib
import unittest


ASSET = Path(__file__).with_name("SH040-cryostasis.toml")


class CryostasisSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.asset = tomllib.loads(ASSET.read_text())
        cls.display = cls.asset["design"]
        cls.collision = cls.asset["nativeDesign"]
        cls.parts = cls.asset["ownership"]["parts"]

    def test_budget_closed_part_ownership_and_native_shell(self):
        for design in (self.display, self.collision):
            self.assertLessEqual(sum(len(face) - 2 for face in design["faces"]), 512)
            self.assertEqual(len(design["faces"]), len(design["faceMaterials"]))
        vertex_end = face_end = 0
        for part in self.parts:
            self.assertEqual(part["vertexStart"], vertex_end)
            self.assertEqual(part["faceStart"], face_end)
            vertex_end += part["vertexCount"]
            face_end += part["faceCount"]
            faces = self.display["faces"][part["faceStart"]:face_end]
            self.assertEqual({i for f in faces for i in f},
                             set(range(part["vertexStart"], vertex_end)))
            edges = Counter((a, b) for f in faces for a, b in zip(f, f[1:] + f[:1]))
            self.assertTrue(all(count == 1 and edges[b, a] == 1
                                for (a, b), count in edges.items()), part["name"])
        self.assertEqual((vertex_end, face_end),
                         (len(self.display["vertices"]), len(self.display["faces"])))
        collision = self.collision
        shell = self.parts[0]
        self.assertEqual(collision["vertices"], self.display["vertices"][:shell["vertexCount"]])
        self.assertEqual(len(collision["faces"]), 92)
        edges = Counter((a, b) for f in collision["faces"] for a, b in zip(f, f[1:] + f[:1]))
        self.assertTrue(all(n == 1 and edges[b, a] == 1 for (a, b), n in edges.items()))
        self.assertTrue(all(len(f) == 3 for f in collision["faces"]))
        self.assertTrue(all("opticalOpacity" not in m for m in collision["materials"]))
        self.assertEqual(collision["faces"][:38], self.display["faces"][:38])
        self.assertEqual(collision["faces"][38:40], [[14, 15, 27], [14, 27, 26]])
        self.assertEqual(collision["faces"][40:], self.display["faces"][39:shell["faceCount"]])
        self.assertTrue(set(collision["faceMaterials"]).issubset({0, 2}))

    def test_single_glass_lid_and_recognizable_opaque_occupant_under_it(self):
        self.assertEqual([i for i, m in enumerate(self.display["materials"])
                          if "opticalOpacity" in m], [3])
        self.assertEqual(self.display["materials"][3]["opticalOpacity"], 0.25)
        self.assertTrue(all(m["colour"] & 255 == 255 for m in self.display["materials"]))
        self.assertNotIn("faceTextures", self.display)
        self.assertEqual([i for i, m in enumerate(self.display["faceMaterials"]) if m == 3], [38])
        pane = [self.display["vertices"][i] for i in self.display["faces"][38]]
        self.assertEqual(pane, [[.125, .145, -.285], [-.125, .145, -.285],
                                [-.125, .145, .285], [.125, .145, .285]])
        parts = {part["name"]: part for part in self.parts}
        for name in ("occupant head", "closed left eye", "closed right eye",
                     "frozen occupant insulated torso", "left sleeve", "right sleeve",
                     "left leg", "right leg", "left boot", "right boot"):
            part = parts[name]
            first = part["vertexStart"]
            for x, y, z in self.display["vertices"][first:first + part["vertexCount"]]:
                self.assertTrue(-.114 < x < .114 and -.270 < z < .270 and -.030 <= y < .126,
                                (name, x, y, z))
        self.assertEqual(self.asset["proposal"]["role"], "escape")

    def test_decorative_geometry_is_inside_the_closed_central_shell(self):
        # All display additions lie within the straight central interval.
        # Its convex 12-sided section bounds every segment and triangle of
        # those additions if it contains each of their vertices.
        shell_vertices = self.parts[0]["vertexCount"]
        section = self.collision["vertices"][12:24]
        for x, y, z in self.display["vertices"][shell_vertices:]:
            self.assertLessEqual(abs(z), .285)
            for a, b in zip(section, section[1:] + section[:1]):
                edge = (b[0] - a[0], b[1] - a[1])
                self.assertGreaterEqual(edge[0] * (y - a[1]) - edge[1] * (x - a[0]), -1e-12)
        mount, couch = self.parts[1:3]
        def coordinates(part, axis):
            first = part["vertexStart"]
            return [p[axis] for p in self.display["vertices"][first:first + part["vertexCount"]]]
        self.assertEqual(min(coordinates(mount, 1)), -.160)
        self.assertLess(min(coordinates(couch, 1)), max(coordinates(mount, 1)))
        self.assertGreater(min(coordinates(couch, 0)), -.125)
        self.assertLess(max(coordinates(couch, 0)), .125)


if __name__ == "__main__":
    unittest.main()
