"""Unexecuted method candidate. Requires a separately pinned Root authority FIRST.

Only source engineering is computed: no mesh creation, queries, native application,
original creators, adaptive precision, geometry edits, or previous successful rows.
"""
import argparse
from decimal import (
    Decimal, DecimalException, localcontext, ROUND_HALF_EVEN, ROUND_CEILING,
    InvalidOperation, DivisionByZero, Overflow, Underflow, Subnormal, Clamped, FloatOperation,
)
import hashlib
import json
import math
import os
from pathlib import Path
import tempfile
import tomllib


ROOT = Path(__file__).resolve().parent
INPUT = ROOT / "decimal80-061-122-method-input-first.json"
INPUT_SHA256 = "3116ad99f94910fbc0c111fbfb539af0cec9998388f0527e0bff4f45bc8d1583"
POLICY_SHA256 = "8f864a534d96733218e126a480353441ac77d7f169936db9a7f4df821a2a2044"
METHOD = "decimal80-original-origin-moments-v1"
D = Decimal
ZERO, ONE = D(0), D(1)
TOLERANCE = D("1e-9")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def bounded_bytes(path, maximum, pin=None):
    path = Path(path)
    assert not path.is_symlink() and path.is_file()
    assert path.stat().st_size <= maximum
    with path.open("rb") as stream:
        data = stream.read(maximum + 1)
    assert len(data) <= maximum
    if pin is not None:
        assert len(data) == pin["bytes"] and digest(data) == pin["sha256"]
    return data


def execution_gate(authority_path):
    """Process provenance guard, not a cryptographic authorization capability."""
    authority = json.loads(bounded_bytes(authority_path, 65536))
    assert authority["executionAuthorized"] is True
    assert authority["scopeIDs"] == ["SH061", "SH122"]
    assert authority["method"] == METHOD
    for key in ("rootDecision", "sourceMethodReview", "methodFirst"):
        pin = authority[key]
        bounded_bytes(pin["path"], 1_048_576, pin)
    method_first = json.loads(Path(authority["methodFirst"]["path"]).read_bytes())
    own = Path(__file__).read_bytes()
    assert digest(own) == method_first["source"]["sha256"]
    assert len(own) == method_first["source"]["bytes"]
    raw = bounded_bytes(INPUT, 1_048_576)
    assert digest(raw) == INPUT_SHA256 == method_first["input"]["sha256"]
    inputs = json.loads(raw)
    assert inputs["method"] == METHOD and inputs["precisionDigits"] == 80
    assert inputs["rounding"] == "ROUND_HALF_EVEN"
    assert inputs["toleranceExactDecimal"] == "1e-9"
    assert [row["id"] for row in inputs["rows"]] == ["SH061", "SH122"]
    for row in inputs["rows"]:
        parent_pin = row["parentRoleMap"]
        parent = json.loads(bounded_bytes(parent_pin["path"], 1_048_576, parent_pin))
        assert parent["proposalMarkdownSHA256"] == POLICY_SHA256
        original = next(item for item in parent["rows"] if item["id"] == row["id"])
        keys = row["scopeSemanticRoleKeys"]
        assert {key: row[key] for key in keys} == {key: original[key] for key in keys}
        semantic = json.dumps({key: original[key] for key in keys}, sort_keys=True,
                              separators=(",", ":")).encode()
        assert digest(semantic) == row["parentSemanticRoleSHA256"]
        assert row["scaleExact"] == ("20" if row["id"] == "SH061" else "1")
        assert type(row["scale"]) is int and row["scale"] == (20 if row["id"] == "SH061" else 1)
        assert row["sourceCoordinateUnits"] == (None if row["id"] == "SH061" else "metres")
    return inputs


def close_decimal(left, right):
    # Same original-origin per-entry comparison, including near-zero entries.
    return abs(left - right) <= TOLERANCE * max(ONE, abs(left), abs(right))


def analytic_triangle(a, b, c, mass):
    sums = [a[i] + b[i] + c[i] for i in range(3)]
    first = [mass * value / D(3) for value in sums]
    second = [
        mass * (sums[i] * sums[j] + a[i] * a[j] + b[i] * b[j] + c[i] * c[j]) / D(12)
        for i in range(3) for j in range(3)
    ]
    return first, second


def quadrature_triangle(a, b, c, mass, charge):
    # Independently construct three degree-two quadrature points from the corners.
    # No analytic sums, first moments or second moments enter this function.
    corners = (a, b, c)
    checked_mass = ZERO
    first, second = [ZERO] * 3, [ZERO] * 9
    for heavy in range(3):
        charge("quadratureMomentEvaluations")
        point = [
            (D(4) * corners[heavy][i] + corners[(heavy + 1) % 3][i]
             + corners[(heavy + 2) % 3][i]) / D(6)
            for i in range(3)
        ]
        weight = mass / D(3)
        checked_mass += weight
        for i in range(3):
            first[i] += weight * point[i]
            for j in range(3):
                second[3 * i + j] += weight * point[i] * point[j]
    return checked_mass, first, second


def leading_minors(tensor):
    a, b, c, d, e, f, g, h, i = tensor
    return [a, a * e - b * d, a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)]


def float_bridge(record, charge):
    def convert(value):
        if isinstance(value, Decimal):
            charge("outputFloatConversions")
            number = float(value)
            assert math.isfinite(number), "Non-finite Float64 output bridge"
            return number
        if isinstance(value, list):
            return [convert(item) for item in value]
        if isinstance(value, dict):
            return {key: convert(item) for key, item in value.items()}
        assert not isinstance(value, float), "Unexpected earlier Float64 arithmetic"
        return value

    value = convert(record)
    charge("floatBridgeChecks")
    mass, dry, reserve = value["unroundedMassKg"], value["dryMassKilograms"], value["roundingReserveKg"]
    assert mass > 0 and 0 < dry <= 2**63 - 1
    assert math.isfinite(float(dry)) and int(float(dry)) == dry
    assert math.ceil(mass) == dry, "Decimal/Float64 ceiling boundary: refuse, never adjust"
    assert 0 <= reserve < 1, "Float64 reserve boundary: refuse, never clamp"

    def close_float(left, right):
        return math.isfinite(left) and math.isfinite(right) and abs(left - right) <= 1e-9 * max(1, abs(left), abs(right))

    assert close_float(value["stockMassKg"] + value["intrinsicHardwareMassKg"], mass)
    assert close_float(mass + reserve, float(dry))
    centre = value["centreOfMassMetres"]
    tensor = value["inertiaAboutCentreOfMassKgM2"]
    origin = value["sourceOriginInertiaBeforeReserveKgM2"]
    norm = sum(component * component for component in centre)
    for i in range(3):
        for j in range(3):
            assert close_float(tensor[3 * i + j], tensor[3 * j + i])
            reconstructed = tensor[3 * i + j] + mass * ((norm if i == j else 0) - centre[i] * centre[j])
            assert close_float(reconstructed, origin[3 * i + j])
    assert all(math.isfinite(minor) and minor > 0 for minor in leading_minors(tensor))
    return value


def calculate(row, used, total, inputs):
    def charge(key, count=1):
        assert used[key] + count <= row["operationBounds"][key], (row["id"], key, "row bound")
        assert total[key] + count <= inputs["totalOperationBounds"][key], (key, "whole bound")
        used[key] += count
        total[key] += count

    with localcontext() as context:
        context.prec = 80
        context.rounding = ROUND_HALF_EVEN
        context.Emin, context.Emax = -999999, 999999
        context.capitals, context.clamp = 1, 0
        for signal in context.traps:
            context.traps[signal] = False
        for signal in (InvalidOperation, DivisionByZero, Overflow, Underflow, Subnormal, Clamped, FloatOperation):
            context.traps[signal] = True
        context.clear_flags()
        source = row["source"]
        raw = bounded_bytes(source["geometryPath"], source["geometryBytes"],
                            {"bytes": source["geometryBytes"], "sha256": source["geometrySHA256"]})
        component_raw = bounded_bytes(source["componentPath"], source["componentBytes"],
                                      {"bytes": source["componentBytes"], "sha256": source["componentSHA256"]})
        assert json.loads(component_raw)["design"] == row["components"]
        charge("sourceParses")
        # Unused floating literals remain strings too; no input has a float roundtrip.
        document = tomllib.loads(raw.decode("utf-8"), parse_float=str)
        assert document["proposal"]["id"] == row["id"]
        assert document["proposal"].get("coordinateUnits") == row["sourceCoordinateUnits"]
        assert document["proposal"]["forwardAxis"] == "+Z" and document["proposal"]["upAxis"] == "+Y"
        design = document["design"]
        assert len(design["vertices"]) == source["detailedVertexBound"]
        assert len(design["faces"]) == len(design["faceMaterials"]) == source["detailedFaceBound"]
        assert len(design["materials"]) == len(row["faceStockAssignments"])
        coefficients = []
        for assignment in row["faceStockAssignments"]:
            index = assignment["materialIndex"]
            assert index == len(coefficients)
            assert design["materials"][index]["name"] == assignment["exactSourceMaterialName"]
            assert type(assignment["kgPerSquareMetre"]) is int and assignment["kgPerSquareMetre"] in (5, 14)
            coefficients.append(D(assignment["kgPerSquareMetre"]))
        scale = D(row["scaleExact"])
        assert scale == (D(20) if row["id"] == "SH061" else ONE)
        vertices = []
        for original in design["vertices"]:
            assert len(original) == 3
            point = []
            for token in original:
                assert type(token) in (str, int) and len(str(token)) <= 128
                charge("coordinateConversions")
                coordinate = D(token)
                assert coordinate.is_finite()
                charge("scaledCoordinateEvaluations")
                coordinate *= scale
                assert coordinate.is_finite()
                point.append(coordinate)
            vertices.append(point)
        parts = []
        next_face = next_vertex = 0
        for component in row["components"]:
            assert component["faceStart"] == next_face and component["vertexStart"] == next_vertex
            area = mass = checked_mass = ZERO
            area_first, first, checked_first = [ZERO] * 3, [ZERO] * 3, [ZERO] * 3
            second, checked_second = [ZERO] * 9, [ZERO] * 9
            end = component["vertexStart"] + component["vertexCount"]
            for face_index in range(next_face, next_face + component["faceCount"]):
                face = design["faces"][face_index]
                assert len(face) == 3
                for vertex in face:
                    charge("faceIndexChecks")
                    assert type(vertex) is int and component["vertexStart"] <= vertex < end
                a, b, c = [vertices[index] for index in face]
                u, v = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
                cross = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
                charge("triangleAreaEvaluations")
                charge("squareRoots")
                triangle_area = sum((value * value for value in cross), ZERO).sqrt() / D(2)
                assert triangle_area.is_finite() and triangle_area > 0, (row["id"], component["name"], face_index, "nonpositive source area")
                charge("faceMaterialChecks")
                material = design["faceMaterials"][face_index]
                assert type(material) is int and 0 <= material < len(coefficients)
                triangle_mass = triangle_area * coefficients[material]
                charge("analyticMomentEvaluations")
                analytic_first, analytic_second = analytic_triangle(a, b, c, triangle_mass)
                quadrature_mass, quadrature_first, quadrature_second = quadrature_triangle(a, b, c, triangle_mass, charge)
                area += triangle_area
                mass += triangle_mass
                checked_mass += quadrature_mass
                for i in range(3):
                    area_first[i] += triangle_area * (a[i] + b[i] + c[i]) / D(3)
                    first[i] += analytic_first[i]
                    checked_first[i] += quadrature_first[i]
                for i in range(9):
                    second[i] += analytic_second[i]
                    checked_second[i] += quadrature_second[i]
            assert area.is_finite() and mass.is_finite() and area > 0 and mass > 0
            residual = ZERO
            for left, right in zip([mass] + first + second, [checked_mass] + checked_first + checked_second):
                charge("momentConsistencyChecks")
                assert left.is_finite() and right.is_finite()
                assert close_decimal(left, right), (row["id"], component["name"], "original-origin moment consistency")
                residual = max(residual, abs(left - right))
            parts.append({"name": component["name"], "areaSquareMetres": area,
                          "stockMassKg": mass, "areaCentroidMetres": [value / area for value in area_first],
                          "massFirst": first, "massSecond": second, "verificationSecond": checked_second,
                          "verificationMass": checked_mass, "verificationFirst": checked_first,
                          "maximumOriginalOriginMomentDifferenceDecimal": str(residual),
                          "sourceFaceStart": component["faceStart"], "sourceFaceCount": component["faceCount"]})
            next_face += component["faceCount"]
            next_vertex += component["vertexCount"]
        assert next_face == len(design["faces"]) and next_vertex == len(vertices)
        stock_mass = sum((part["stockMassKg"] for part in parts), ZERO)
        mass = stock_mass
        first = [sum((part["massFirst"][i] for part in parts), ZERO) for i in range(3)]
        second = [sum((part["massSecond"][i] for part in parts), ZERO) for i in range(9)]
        hardware = []
        for item in row["intrinsicHardware"]:
            charge("hardwareAllocations")
            assert type(item["count"]) is int and type(item["eachKg"]) is int
            assert item["count"] > 0 and item["eachKg"] > 0
            component = parts[item["anchorComponent"]]
            assert component["name"] == item["anchorName"]
            point = component["areaCentroidMetres"]
            weight = D(item["count"]) * D(item["eachKg"])
            mass += weight
            for i in range(3):
                first[i] += weight * point[i]
                for j in range(3):
                    second[3 * i + j] += weight * point[i] * point[j]
            hardware.append({**item, "massKg": weight, "anchorMetres": point})
        assert mass.is_finite() and mass > 0
        centre = [value / mass for value in first]
        trace = second[0] + second[4] + second[8]
        origin = [(trace if i == j else ZERO) - second[3 * i + j] for i in range(3) for j in range(3)]
        norm = sum((value * value for value in centre), ZERO)
        tensor = [origin[3 * i + j] - mass * ((norm if i == j else ZERO) - centre[i] * centre[j])
                  for i in range(3) for j in range(3)]
        charge("decimalTensorChecks")
        assert all(value.is_finite() for value in centre + origin + tensor)
        for i in range(3):
            for j in range(3):
                assert close_decimal(tensor[3 * i + j], tensor[3 * j + i])
        minors = leading_minors(tensor)
        assert all(value.is_finite() and value > 0 for value in minors)
        dry_mass = int(mass.to_integral_value(rounding=ROUND_CEILING))
        reserve = D(dry_mass) - mass
        assert ZERO <= reserve < ONE
        record = {"schemaVersion": 1, "id": row["id"],
                  "status": "NEW_AUTHORED_SOURCE_BUDGET_NOT_NATIVE_QUALIFICATION",
                  "contractSHA256": row["contractSHA256"], "detailedSourceSHA256": source["geometrySHA256"],
                  "componentSourceSHA256": source["componentSHA256"], "roleMapSHA256": INPUT_SHA256,
                  "policyProposalSHA256": POLICY_SHA256, "coordinateUnits": "metres",
                  "metresPerSourceUnit": row["scale"], "sourceOriginUnchanged": True,
                  "sourceStockAreaSquareMetres": sum((part["areaSquareMetres"] for part in parts), ZERO),
                  "stockMassKg": stock_mass, "intrinsicHardwareMassKg": mass - stock_mass,
                  "unroundedMassKg": mass, "roundingReserveKg": reserve, "dryMassKilograms": dry_mass,
                  "centreOfMassMetres": centre, "reserveLocationMetres": list(centre),
                  "inertiaAboutCentreOfMassKgM2": tensor, "sourceOriginInertiaBeforeReserveKgM2": origin,
                  "positiveLeadingPrincipalMinors": minors, "stockComponents": parts, "intrinsicHardware": hardware,
                  "zeroAreaSourceFaces": 0, "sourceGeometryNotEdited": True, "method": METHOD,
                  "precisionDigits": 80, "rounding": "ROUND_HALF_EVEN",
                  "decimalAudit": {"unroundedMassKg": str(mass), "centreOfMassMetres": [str(value) for value in centre],
                                   "inertiaAboutCentreOfMassKgM2": [str(value) for value in tensor]},
                  "contextFlags": {signal.__name__: flag for signal, flag in context.flags.items()},
                  "nativeQualification": "UNRUN; empty source estimate, no occupied/loaded mass or actor grant."}
        if row["sourceCoordinateUnits"] is None:
            record.update(sourceCoordinateUnits="Relative original units; no recovered SI declaration.",
                          metresPerSourceUnitExact=row["scaleExact"],
                          scaleStatus="EXISTING_PER_ID_CALIBRATION_RETAINED_NO_R3_TARGET_FIT")
        payload = float_bridge(record, charge)
        charge("resultRecords")
        payload["operations"] = dict(used)
        encoded = (json.dumps(payload, sort_keys=True, indent=2, allow_nan=False) + "\n").encode()
        assert len(encoded) <= inputs["maximumRecordBytes"], "Output bound: refuse without truncation"
        return encoded


def artifact_status(path):
    """An error is not evidence that the final artifact is absent."""
    try:
        metadata = path.lstat()
        return {"presence": "PRESENT", "bytes": metadata.st_size}
    except FileNotFoundError:
        return {"presence": "ABSENT"}
    except OSError as error:
        return {"presence": "UNKNOWN", "inspectionError": type(error).__name__ + ": " + str(error)[:512]}


def publish_exclusive(target, encoded):
    """Verify an owned temporary inode before atomically linking a new final name."""
    descriptor, name = tempfile.mkstemp(prefix="." + target.name + ".", suffix=".tmp", dir=target.parent)
    temporary = Path(name)
    identity = None
    try:
        identity = os.fstat(descriptor)
        stream = os.fdopen(descriptor, "w+b")
        descriptor = None
        with stream:
            if stream.write(encoded) != len(encoded):
                raise OSError("Incomplete temporary artifact write")
            stream.flush()
            os.fsync(stream.fileno())
            stream.seek(0)
            if stream.read(len(encoded) + 1) != encoded:
                raise OSError("Temporary artifact byte verification failed")
        # link is atomic and fails if any final entry already exists, including a symlink.
        os.link(temporary, target)
    finally:
        try:
            if descriptor is not None:
                os.close(descriptor)
        finally:
            metadata = temporary.lstat()
            if identity is None or (metadata.st_dev, metadata.st_ino) != (identity.st_dev, identity.st_ino):
                raise OSError("Temporary ownership uncertain; entry retained without deletion")
            temporary.unlink()
            directory = os.open(target.parent, os.O_RDONLY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--authority-first", required=True)
    arguments = parser.parse_args()
    inputs = execution_gate(arguments.authority_first)
    output = ROOT / inputs["outputDirectory"]
    result_path = ROOT / inputs["resultFile"]
    assert not output.exists() and not result_path.exists(), "No unchanged retry or overwrite"
    output.mkdir()
    total = {key: 0 for key in inputs["totalOperationBounds"]}
    results = []
    for row in inputs["rows"]:
        used = {key: 0 for key in row["operationBounds"]}
        target = output / (row["id"] + ".json")
        publication_attempted = False
        try:
            encoded = calculate(row, used, total, inputs)
            publication_attempted = True
            publish_exclusive(target, encoded)
            results.append({"id": row["id"], "status": "AUTHORED_SOURCE_BUDGET", "bytes": len(encoded),
                            "sha256": digest(encoded), "file": str(target.relative_to(ROOT)), "operations": dict(used)})
        except (AssertionError, DecimalException, ArithmeticError, KeyError, ValueError, OSError) as error:
            artifact = artifact_status(target)
            status = ("STOPPED_NO_MASS_RECORD" if not publication_attempted and artifact["presence"] == "ABSENT"
                      else "PUBLICATION_FAILED" if publication_attempted else "STOPPED_ARTIFACT_UNCERTAIN")
            results.append({"id": row["id"], "status": status, "artifact": artifact,
                            "error": type(error).__name__ + ": " + str(error)[:512], "operations": dict(used)})
    result = {"status": "ONE_NEW_FIXED_DECIMAL80_SOURCE_PASS_NOT_NATIVE_QUALIFICATION", "method": METHOD,
              "roleMapSHA256": INPUT_SHA256, "authoringSourceSHA256": digest(Path(__file__).read_bytes()),
              "results": results, "used": total, "caps": inputs["totalOperationBounds"],
              "retries": 0, "precisionEscalations": 0, "capRaises": 0, "toleranceChanges": 0,
              "sourceGeometryWrites": 0, "originalCreatorImportsOrExecutions": 0, "nativeCompilerRendererTests": 0}
    try:
        publish_exclusive(result_path, (json.dumps(result, sort_keys=True, indent=2) + "\n").encode())
    except OSError as error:
        print(json.dumps({"status": "RESULT_PUBLICATION_FAILED", "artifact": artifact_status(result_path),
                          "error": type(error).__name__ + ": " + str(error)[:512], "results": results}))
        raise SystemExit(1)
    print(json.dumps({"records": sum(item["status"] == "AUTHORED_SOURCE_BUDGET" for item in results),
                      "stops": [item for item in results if item["status"] != "AUTHORED_SOURCE_BUDGET"]}))


if __name__ == "__main__":
    main()
