import 'package:latlong2/latlong.dart';

/// Vehicle types of a lot (`parking_lots.vehicle_types`, SPEC-001 §5).
enum VehicleType {
  motorbike,
  car;

  static VehicleType? fromDb(String value) => switch (value) {
        'motorbike' => VehicleType.motorbike,
        'car' => VehicleType.car,
        _ => null,
      };
}

/// Pin style (SPEC-001 BR-6).
enum PinKind { motorbike, car, both }

/// One row of the `nearby_lots` RPC (SPEC-001 §5).
class ParkingLot {
  const ParkingLot({
    required this.id,
    required this.name,
    required this.position,
    required this.vehicleTypes,
    this.address,
    this.isVerified = false,
    this.customersOnly = false,
    this.distanceM = 0,
  });

  /// Parses one RPC row. Throws [FormatException] on a malformed row.
  factory ParkingLot.fromRpc(Map<String, dynamic> row) {
    final id = row['id'];
    final name = row['name'];
    final lat = row['lot_lat'];
    final lng = row['lot_lng'];
    final types = row['vehicle_types'];
    if (id is! String || name is! String || lat is! num || lng is! num) {
      throw const FormatException('nearby_lots: malformed row');
    }
    return ParkingLot(
      id: id,
      name: name,
      address: row['address'] as String?,
      position: LatLng(lat.toDouble(), lng.toDouble()),
      vehicleTypes: {
        if (types is List)
          for (final t in types)
            if (t is String && VehicleType.fromDb(t) != null)
              VehicleType.fromDb(t)!,
      },
      isVerified: row['is_verified'] == true,
      // BR-16 (v0.4): missing or null (older backend) counts as false.
      customersOnly: row['customers_only'] == true,
      distanceM: (row['distance_m'] as num?)?.round() ?? 0,
    );
  }

  final String id;
  final String name;
  final String? address;
  final LatLng position;
  final Set<VehicleType> vehicleTypes;
  final bool isVerified;

  /// OSM `access=customers` lot (SPEC-001 BR-16): same pin style as other
  /// lots (BR-6); the mini card shows `label_customers_only`.
  final bool customersOnly;

  /// Distance from the **search point** (RPC). The card uses BR-11 instead.
  final int distanceM;

  /// BR-6: motorbike-only, car-only or both. A lot without known types is
  /// shown as "both" (the DB requires at least one type, SPEC-001 §5).
  PinKind get pinKind {
    final moto = vehicleTypes.contains(VehicleType.motorbike);
    final car = vehicleTypes.contains(VehicleType.car);
    if (moto && !car) return PinKind.motorbike;
    if (car && !moto) return PinKind.car;
    return PinKind.both;
  }
}
