class Atom {
  final String element;
  final double x;
  final double y;
  final double z;

  Atom({
    required this.element,
    required this.x,
    required this.y,
    required this.z,
  });
}

class Bond {
  final int atom1;
  final int atom2;
  final int order;

  Bond({
    required this.atom1,
    required this.atom2,
    required this.order,
  });
}

class Molecule {
  final List<Atom> atoms;
  final List<Bond> bonds;

  Molecule({
    required this.atoms,
    required this.bonds,
  });
}

class StructureInfo {
  final int id;
  final DateTime createdAt;

  final String name;
  final String type;
  final String info;

  const StructureInfo({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.type,
    required this.info,
  });

  factory StructureInfo.fromJson(
    Map<String, dynamic> json,
  ) {
    return StructureInfo(
      id: json['id'] as int,
      createdAt: DateTime.parse(
        json['created_at'] as String,
      ),
      name: json['name'] as String,
      type: json['type'] as String,
      info: json['info'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'name': name,
      'type': type,
      'info': info,
    };
  }

  @override
  String toString() {
    return 'StructureInfo('
        'id: $id, '
        'name: $name, '
        'type: $type'
        ')';
  }
}