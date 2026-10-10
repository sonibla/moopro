class BankIcon {
  final String id;
  final String name;

  final List<String> aliases;

  const BankIcon(this.id, this.name, {this.aliases = const []});

  String get assetPath => 'assets/bank_icons/$id.svg';
}

const Map<String, BankIcon> bankIconRegistry = {
  'air_liquide': BankIcon(
    'air_liquide',
    'Air Liquide',
    aliases: ['airliquide'],
  ),
  'binance': BankIcon('binance', 'Binance', aliases: ['crypto', 'exchange']),
  'boursedirect': BankIcon(
    'boursedirect',
    'Bourse Direct',
    aliases: ['bourse direct', 'bourse'],
  ),
  'boursorama_boursobank': BankIcon(
    'boursorama_boursobank',
    'BoursoBank',
    aliases: ['boursorama', 'bourso'],
  ),
  'coinbase': BankIcon('coinbase', 'Coinbase', aliases: ['crypto', 'exchange']),
  'credit_agricole': BankIcon(
    'credit_agricole',
    'Crédit Agricole',
    aliases: ['credit agricole', 'ca'],
  ),
  'degiro': BankIcon('degiro', 'DEGIRO', aliases: ['broker']),
  'fortuneo': BankIcon('fortuneo', 'Fortuneo'),
  'n26': BankIcon('n26', 'N26'),
  'trade_republic': BankIcon(
    'trade_republic',
    'Trade Republic',
    aliases: ['traderepublic', 'broker'],
  ),
};
