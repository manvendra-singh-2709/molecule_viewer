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