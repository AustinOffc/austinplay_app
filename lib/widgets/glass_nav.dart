import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../core/icons.dart';
import '../core/layout.dart';
import '../core/theme/tokens.dart';

class NavItem {
  const NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

const List<NavItem> kNavItems = [
  NavItem('Beranda', AppIcons.home),
  NavItem('Cari', AppIcons.search),
  NavItem('Koleksi', AppIcons.library),
  NavItem('Room', AppIcons.room),
  NavItem('Chat', AppIcons.chat),
  NavItem('Profil', AppIcons.profile),
];

/// Bottom nav melayang. Tap = pindah tab. Tekan lama + geser = "gelembung" liquid, lepas pindah ke tab terdekat.
class GlassNav extends StatefulWidget {
  const GlassNav({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  State<GlassNav> createState() => _GlassNavState();
}

class _GlassNavState extends State<GlassNav> {
  bool _pressing = false;
  double _dx = 0;

  int _indexAt(double dx, double width) {
    final w = width / kNavItems.length;
    return (dx / w).floor().clamp(0, kNavItems.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: T.shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, .82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: T.glassEdge),
              ),
              child: LayoutBuilder(builder: (context, c) {
                final itemW = c.maxWidth / kNavItems.length;
                const bubbleW = 66.0;
                final bubbleLeft = (_dx - bubbleW / 2).clamp(0.0, c.maxWidth - bubbleW);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => widget.onTap(_indexAt(d.localPosition.dx, c.maxWidth)),
                  onLongPressStart: (d) => setState(() {
                    _pressing = true;
                    _dx = d.localPosition.dx;
                  }),
                  onLongPressMoveUpdate: (d) => setState(() => _dx = d.localPosition.dx),
                  onLongPressEnd: (d) {
                    final i = _indexAt(d.localPosition.dx, c.maxWidth);
                    setState(() => _pressing = false);
                    widget.onTap(i);
                  },
                  onLongPressCancel: () => setState(() => _pressing = false),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: _pressing ? Duration.zero : T.dur,
                        curve: T.ease,
                        left: bubbleLeft,
                        top: 9,
                        child: AnimatedScale(
                          duration: T.dur,
                          curve: T.ease,
                          scale: _pressing ? 1 : 0.6,
                          child: AnimatedOpacity(
                            duration: T.dur,
                            opacity: _pressing ? 1 : 0,
                            child: Container(
                              width: bubbleW,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: const Color.fromRGBO(255, 255, 255, .55),
                                border: Border.all(color: const Color.fromRGBO(255, 255, 255, .95)),
                                boxShadow: T.shadowSm,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < kNavItems.length; i++)
                            SizedBox(
                              width: itemW,
                              child: _NavTile(item: kNavItems[i], active: i == widget.index),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.active});
  final NavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? T.accent2 : T.ink3;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: T.dur,
          curve: T.ease,
          width: 50,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? T.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(item.icon, size: 22, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.1,
            color: color,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Rail vertikal untuk layar lebar (≥1024dp). Gaya sama dengan nav bawah: kaca, tanpa glow.
class GlassRail extends StatelessWidget {
  const GlassRail({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(12 + pad.left, 12 + pad.top, 0, 12 + pad.bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: T.shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: kRailWidth - 12,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, .82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: T.glassEdge),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < kNavItems.length; i++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: SizedBox(
                        height: 66,
                        child: _NavTile(item: kNavItems[i], active: i == index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
