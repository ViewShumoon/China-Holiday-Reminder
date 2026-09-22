/// 设置页脚手架：MD3 大标题折叠栏 + 可弹滚动内容。
/// FlexibleSpaceBar 的标题随折叠连续缩放位移：展开时贴左（16），
/// 折叠过程中 titlePadding 起点随滚动进度插值到 leading 之后（72）。
/// 内容不足时会补足到「视口高度 - 折叠后标题栏高度（状态栏 inset + 工具栏）」，
/// 保证恰好折叠到最小、首个条目不被遮挡，继续拖动即弹性回弹。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class SettingsPageScaffold extends StatefulWidget {
  const SettingsPageScaffold({
    required this.title,
    required this.children,
    this.expandedHeight = 160,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final double expandedHeight;

  @override
  State<SettingsPageScaffold> createState() => _SettingsPageScaffoldState();
}

class _SettingsPageScaffoldState extends State<SettingsPageScaffold> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canPop = Navigator.of(context).canPop();
    final collapsedHeight = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final collapseExtent = widget.expandedHeight - kToolbarHeight;
    // 折叠到位后标题需避开 leading（含圆形返回按钮），与 NavigationToolbar 对齐。
    final collapsedStartPadding = canPop ? 72.0 : 16.0;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return CustomScrollView(
            controller: _controller,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                floating: true,
                expandedHeight: widget.expandedHeight,
                automaticallyImplyLeading: false,
                leading: canPop
                    ? IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        icon: const Icon(Icons.arrow_back),
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          shape: const CircleBorder(),
                        ),
                      )
                    : null,
                // 折叠后与页面背景保持一致（不随 scrolled-under 变色）。
                backgroundColor: theme.scaffoldBackgroundColor,
                scrolledUnderElevation: 0,
                flexibleSpace: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final progress = _controller.hasClients
                        ? (_controller.position.pixels / collapseExtent).clamp(
                            0.0,
                            1.0,
                          )
                        : 0.0;
                    return FlexibleSpaceBar(
                      title: Text(widget.title),
                      titlePadding: EdgeInsetsDirectional.only(
                        start:
                            16.0 +
                            (collapsedStartPadding - 16.0) * progress,
                        bottom: 16.0,
                      ),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max<double>(
                      0,
                      constraints.maxHeight - collapsedHeight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widget.children,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
