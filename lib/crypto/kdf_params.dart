class KdfParams {
  final int memory;
  final int iterations;
  final int parallelism;

  const KdfParams({
    required this.memory,
    required this.iterations,
    required this.parallelism,
  });

  static const KdfParams defaults = KdfParams(
    memory: 64 * 1024,
    iterations: 3,
    parallelism: 4,
  );

  Map<String, dynamic> toJson() => {
    'memory': memory,
    'iterations': iterations,
    'parallelism': parallelism,
  };

  factory KdfParams.fromJson(Map<String, dynamic> json) => KdfParams(
    memory: json['memory'] as int,
    iterations: json['iterations'] as int,
    parallelism: json['parallelism'] as int,
  );

  @override
  bool operator ==(Object other) =>
      other is KdfParams &&
      memory == other.memory &&
      iterations == other.iterations &&
      parallelism == other.parallelism;

  @override
  int get hashCode => Object.hash(memory, iterations, parallelism);
}
