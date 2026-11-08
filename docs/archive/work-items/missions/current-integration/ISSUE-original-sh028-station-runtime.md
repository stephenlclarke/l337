# Original SH028 station runtime join

The main-station renderer, entry solver and collision paths share MainStationGeometry, which currently supplies the old cube and aperture. Bind that producer to the complete original Lion Citadel SH028 resource, using its same nativeDesign and nativeDocking. Add only the existing Port Codable/validity support and one optional catalogue field with a strict SH028 loader guard.

The resource uses a newly authored uniform80m/source-unit estimate,488native triangles and a real+Z harbour. Its one-sided detailed-native vertex approximation error reaches10.48793m; this source join does not prove swept docking or render acceptance. Separate RRS-derived station replacement remains required.
