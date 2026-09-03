import 'package:flutter/material.dart';
import '../models/merchant.dart';

/// Navigation item definition for the dashboard sidebar.
class SidebarItem {
  const SidebarItem({
    required this.title,
    required this.icon,
    required this.route,
  });

  final String title;
  final IconData icon;
  final String route;
}

/// Reusable sidebar for desktop, tablet, and drawer views.
class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({
    super.key,
    required this.activeRoute,
    required this.onNavigate,
    this.merchant,
    required this.onSignOut,
  });

  /// Currently highlighted route name.
  final String activeRoute;

  /// Callback when a sidebar navigation item is selected.
  final ValueChanged<String> onNavigate;

  /// Merchant profile data for identity display.
  final Merchant? merchant;

  /// Sign out callback.
  final VoidCallback onSignOut;

  static const List<SidebarItem> items = [
    SidebarItem(
      title: 'Dashboard',
      icon: Icons.dashboard_rounded,
      route: '/dashboard',
    ),
    SidebarItem(
      title: 'Transactions',
      icon: Icons.receipt_long_rounded,
      route: '/transactions',
    ),
    SidebarItem(
      title: 'Recovery',
      icon: Icons.published_with_changes_rounded,
      route: '/recovery',
    ),
    SidebarItem(
      title: 'Simulator',
      icon: Icons.auto_awesome_rounded,
      route: '/simulator',
    ),
    SidebarItem(
      title: 'Settings',
      icon: Icons.tune_rounded,
      route: '/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Modern dark slate
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'REVIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Payment Recovery Engine',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF1E293B), height: 1),
          const SizedBox(height: 16),

          // Section Label
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Text(
              'PLATFORM NAVIGATION',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.0,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),

          // Nav Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = activeRoute == item.route;

                return InkWell(
                  onTap: () => onNavigate(item.route),
                  borderRadius: BorderRadius.circular(8.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 10.0,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8.0),
                      border: isSelected
                          ? Border.all(color: const Color(0xFF3B82F6), width: 1.0)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: isSelected
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                              fontSize: 14.0,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF38BDF8),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Merchant & Logout Card
          const Divider(color: Color(0xFF1E293B), height: 1),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color(0xFF0B132B),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF2563EB),
                      child: Text(
                        (merchant?.name.isNotEmpty == true)
                            ? merchant!.name[0].toUpperCase()
                            : 'M',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            merchant?.name.isNotEmpty == true
                                ? merchant!.name
                                : 'Active Merchant',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            merchant?.email.isNotEmpty == true
                                ? merchant!.email
                                : 'Connected Account',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFEF4444)),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0x33EF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
