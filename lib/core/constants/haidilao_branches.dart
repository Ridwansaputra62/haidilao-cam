class HaidilaoBranch {
  final String id;
  final String name;
  final String city;
  final String defaultAddress;

  const HaidilaoBranch({
    required this.id,
    required this.name,
    required this.city,
    required this.defaultAddress,
  });
}

class HaidilaoBranches {
  static const List<HaidilaoBranch> list = [
    HaidilaoBranch(
      id: 'gi',
      name: 'Grand Indonesia',
      city: 'Jakarta Pusat',
      defaultAddress: 'Grand Indonesia West Mall Lt. 3A, Jl. M.H. Thamrin No.1',
    ),
    HaidilaoBranch(
      id: 'mta',
      name: 'Mall Taman Anggrek',
      city: 'Jakarta Barat',
      defaultAddress: 'Mall Taman Anggrek Lt. 1, Jl. Letjen S. Parman',
    ),
    HaidilaoBranch(
      id: 'pik',
      name: 'PIK Avenue',
      city: 'Jakarta Utara',
      defaultAddress: 'PIK Avenue Lt. 1, Pantai Indah Kapuk',
    ),
    HaidilaoBranch(
      id: 'gancit',
      name: 'Gandaria City',
      city: 'Jakarta Selatan',
      defaultAddress: 'Gandaria City Mall Lt. UG, Jl. Sultan Iskandar Muda',
    ),
    HaidilaoBranch(
      id: 'mkg',
      name: 'Mall Kelapa Gading 3',
      city: 'Jakarta Utara',
      defaultAddress: 'Mall Kelapa Gading 3 Lt. Ground',
    ),
    HaidilaoBranch(
      id: 'pakuwon',
      name: 'Pakuwon Mall',
      city: 'Surabaya',
      defaultAddress: 'Pakuwon Mall Lt. Ground, Surabaya',
    ),
    HaidilaoBranch(
      id: 'custom',
      name: 'Cabang Haidilao',
      city: 'Indonesia',
      defaultAddress: 'Haidilao Hotpot Store',
    ),
  ];
}
