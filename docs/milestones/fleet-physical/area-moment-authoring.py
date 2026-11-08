"""One frozen 49-source authoring pass. No runtime, query, helper or geometry mutation."""
from pathlib import Path
import hashlib
import json
import math
import tomllib

ROOT = Path(__file__).resolve().parent
MAP = ROOT / "area-moment-role-maps.json"
EXPECTED_MAP = "c70c7d725480d8dd346a5b13799c53b966a50fe32312071cd808f8a4f94baf80"
raw_map = MAP.read_bytes()
assert hashlib.sha256(raw_map).hexdigest() == EXPECTED_MAP
inputs = json.loads(raw_map)
output = ROOT / "calculated-records"
assert not output.exists(), "Refuse overwrite or repeated evaluation"
output.mkdir()
all_used = {key: 0 for key in inputs["totalOperationBounds"]}
results = []

for row in inputs["rows"]:
    used = {key: 0 for key in row["operationBounds"]}
    def charge(key, count=1):
        assert used[key] + count <= row["operationBounds"][key], (row["id"], key)
        assert all_used[key] + count <= inputs["totalOperationBounds"][key], key
        used[key] += count
        all_used[key] += count
    try:
        source = row["source"]
        raw = Path(source["geometryPath"]).read_bytes()
        assert len(raw) == source["geometryBytes"]
        assert hashlib.sha256(raw).hexdigest() == source["geometrySHA256"]
        parts_raw = Path(source["componentPath"]).read_bytes()
        assert hashlib.sha256(parts_raw).hexdigest() == source["componentSHA256"]
        assert json.loads(parts_raw)["design"] == row["components"]
        charge("sourceParses")
        document = tomllib.loads(raw.decode(), parse_float=str)
        assert document["proposal"]["id"] == row["id"]
        assert document["proposal"]["coordinateUnits"] == "metres"
        assert document["proposal"]["forwardAxis"] == "+Z"
        assert document["proposal"]["upAxis"] == "+Y"
        design = document["design"]
        assert len(design["vertices"]) == source["detailedVertexBound"]
        assert len(design["faces"]) == source["detailedFaceBound"]
        assert len(design["faceMaterials"]) == len(design["faces"])
        coefficients = []
        for assignment in row["faceStockAssignments"]:
            index = assignment["materialIndex"]
            assert index == len(coefficients)
            assert design["materials"][index]["name"] == assignment["exactSourceMaterialName"]
            coefficients.append(assignment["kgPerSquareMetre"])
        vertices = []
        for value in design["vertices"]:
            assert len(value) == 3
            charge("coordinateConversions", 3)
            point = [float(x) for x in value]
            assert all(math.isfinite(x) for x in point)
            vertices.append(point)
        parts = []
        next_face = 0
        next_vertex = 0
        zero_faces = 0
        for component in row["components"]:
            assert component["faceStart"] == next_face
            assert component["vertexStart"] == next_vertex
            area = 0.0
            area_first = [0.0] * 3
            mass = 0.0
            first = [0.0] * 3
            second = [0.0] * 9
            check_second = [0.0] * 9
            end = component["vertexStart"] + component["vertexCount"]
            for index in range(component["faceStart"], component["faceStart"] + component["faceCount"]):
                face = design["faces"][index]
                assert len(face) == 3
                for vertex in face:
                    charge("faceIndexChecks")
                    assert type(vertex) is int and component["vertexStart"] <= vertex < end
                a, b, c = [vertices[x] for x in face]
                charge("triangleAreaEvaluations")
                u = [b[i] - a[i] for i in range(3)]
                v = [c[i] - a[i] for i in range(3)]
                cross = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]]
                triangle_area = math.sqrt(sum(x*x for x in cross)) / 2
                assert math.isfinite(triangle_area)
                zero_faces += triangle_area == 0
                material = design["faceMaterials"][index]
                assert type(material) is int and 0 <= material < len(coefficients)
                triangle_mass = triangle_area * coefficients[material]
                sums = [a[i]+b[i]+c[i] for i in range(3)]
                area += triangle_area
                mass += triangle_mass
                for i in range(3):
                    area_first[i] += triangle_area * sums[i] / 3
                    first[i] += triangle_mass * sums[i] / 3
                charge("analyticMomentEvaluations")
                for i in range(3):
                    for k in range(3):
                        second[3*i+k] += triangle_mass * (sums[i]*sums[k]+a[i]*a[k]+b[i]*b[k]+c[i]*c[k]) / 12
                # Independent degree-two triangle quadrature checks the analytic second moment.
                for heavy in range(3):
                    charge("quadratureMomentEvaluations")
                    corners = [a,b,c]
                    point = [sum(corners[j][i]*(2/3 if j == heavy else 1/6) for j in range(3)) for i in range(3)]
                    for i in range(3):
                        for k in range(3):
                            check_second[3*i+k] += triangle_mass * point[i] * point[k] / 3
            assert area > 0 and mass > 0
            assert all(math.isfinite(x) for x in [area,mass]+area_first+first+second+check_second)
            for x,y in zip(second, check_second):
                assert abs(x-y) <= 1e-9 * max(1,abs(x),abs(y)), (row["id"],component["name"])
            parts.append({"name":component["name"],"areaSquareMetres":area,"stockMassKg":mass,
                          "areaCentroidMetres":[x/area for x in area_first],"massFirst":first,
                          "massSecond":second,"verificationSecond":check_second})
            next_face += component["faceCount"]
            next_vertex += component["vertexCount"]
        assert next_face == len(design["faces"]) and next_vertex == len(vertices)
        mass = math.fsum(x["stockMassKg"] for x in parts)
        stock_mass = mass
        first = [math.fsum(x["massFirst"][i] for x in parts) for i in range(3)]
        second = [math.fsum(x["massSecond"][i] for x in parts) for i in range(9)]
        hardware = []
        for item in row["intrinsicHardware"]:
            charge("hardwareAllocations")
            component = parts[item["anchorComponent"]]
            assert component["name"] == item["anchorName"]
            point = component["areaCentroidMetres"]
            weight = item["eachKg"] * item["count"]
            assert weight > 0
            mass += weight
            for i in range(3):
                first[i] += weight * point[i]
                for k in range(3):
                    second[3*i+k] += weight * point[i] * point[k]
            hardware.append({**item,"massKg":weight,"anchorMetres":point})
        assert mass > 0 and math.isfinite(mass)
        centre = [x/mass for x in first]
        trace = second[0]+second[4]+second[8]
        inertia_origin = [(trace if i == k else 0)-second[3*i+k] for i in range(3) for k in range(3)]
        norm = sum(x*x for x in centre)
        inertia = [inertia_origin[3*i+k]-mass*((norm if i == k else 0)-centre[i]*centre[k]) for i in range(3) for k in range(3)]
        assert all(math.isfinite(x) for x in centre+inertia_origin+inertia)
        for i in range(3):
            for k in range(3):
                assert abs(inertia[3*i+k]-inertia[3*k+i]) <= 1e-9*max(1,abs(inertia[3*i+k]))
        a,b,c,d,e,f,g,h,i = inertia
        minors = [a,a*e-b*d,a*(e*i-f*h)-b*(d*i-f*g)+c*(d*h-e*g)]
        assert all(math.isfinite(x) and x > 0 for x in minors)
        dry_mass = math.ceil(mass)
        reserve = dry_mass-mass
        assert 0 <= reserve < 1
        # The explicit reserve is at COM: it changes translational mass, not COM inertia.
        record = {"schemaVersion":1,"id":row["id"],"status":"NEW_AUTHORED_SOURCE_BUDGET_NOT_NATIVE_QUALIFICATION",
                  "contractSHA256":row["contractSHA256"],"detailedSourceSHA256":source["geometrySHA256"],
                  "componentSourceSHA256":source["componentSHA256"],"roleMapSHA256":EXPECTED_MAP,
                  "policyProposalSHA256":inputs["proposalMarkdownSHA256"],"coordinateUnits":"metres",
                  "metresPerSourceUnit":1,"sourceOriginUnchanged":True,"sourceStockAreaSquareMetres":math.fsum(x["areaSquareMetres"]for x in parts),
                  "stockMassKg":stock_mass,"intrinsicHardwareMassKg":mass-stock_mass,
                  "unroundedMassKg":mass,"roundingReserveKg":reserve,"dryMassKilograms":dry_mass,
                  "centreOfMassMetres":centre,"inertiaAboutCentreOfMassKgM2":inertia,
                  "sourceOriginInertiaBeforeReserveKgM2":inertia_origin,
                  "reserveLocationMetres":centre,"positiveLeadingPrincipalMinors":minors,
                  "zeroAreaSourceFaces":zero_faces,"stockComponents":parts,"intrinsicHardware":hardware,
                  "operations":used,"sourceGeometryNotEdited":True,"nativeQualification":"UNRUN; source budget never activates a hull"}
        encoded=(json.dumps(record,indent=2,allow_nan=False)+'\n').encode()
        charge("resultRecords")
        record["operations"]=dict(used)
        encoded=(json.dumps(record,indent=2,allow_nan=False)+'\n').encode()
        target=output/(row["id"]+'.json')
        target.write_bytes(encoded)
        results.append({"id":row["id"],"status":"AUTHORED_SOURCE_BUDGET","file":str(target.relative_to(ROOT)),
                        "sha256":hashlib.sha256(encoded).hexdigest(),"bytes":len(encoded),"dryMassKg":dry_mass,
                        "operations":dict(used)})
    except Exception as error:
        results.append({"id":row["id"],"status":"STOPPED_NO_MASS_RECORD","error":type(error).__name__+': '+str(error)[:512],"operations":dict(used)})
summary={"status":"ONE_BOUNDED_SOURCE_AUTHORING_PASS_NO_NATIVE_OR_ACTIVATION","roleMapSHA256":EXPECTED_MAP,
         "authoringSourceSHA256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),"results":results,
         "used":all_used,"caps":inputs["totalOperationBounds"],"unresolvedSourceMaps":inputs["blocked"],
         "nativeRendererCompilerTestsHelpers":0,"retries":0,"sourceGeometryWrites":0}
(ROOT/'area-moment-results.json').write_text(json.dumps(summary,indent=2)+'\n')
print('Source budgets authored:',sum(x['status']=='AUTHORED_SOURCE_BUDGET' for x in results),'stopped:',sum(x['status']!='AUTHORED_SOURCE_BUDGET'for x in results))
for value in results:
    if value['status']!='AUTHORED_SOURCE_BUDGET':print(value['id'],value['error'])
