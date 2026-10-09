class Channel {
  final String name;
  final String url;
  final String logo;
  final String group;
  final String? userAgent;
  final String? referer;

  Channel({
    required this.name,
    required this.url,
    required this.logo,
    required this.group,
    this.userAgent,
    this.referer,
  });
}
