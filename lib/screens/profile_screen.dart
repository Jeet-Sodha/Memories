import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/supabase_config.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/profile_service.dart';
import '../state/memory_store.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../widgets/animations.dart';
import '../widgets/app_states.dart';
import '../widgets/private_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = ProfileService();
  final _auth = AuthService();

  Profile? _profile;
  bool _loading = true;
  bool _uploading = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _service.fetchProfile();
      if (mounted) setState(() => _profile = p);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeAvatar() async {
    try {
      final x = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 1024);
      if (x == null) return;
      setState(() => _uploading = true);
      final path = await _service.uploadAvatar(File(x.path),
          oldPath: _profile?.avatarPath);
      if (!mounted) return;
      setState(() {
        _profile = Profile(
          id: _profile?.id ?? '',
          username: _profile?.username,
          displayName: _profile?.displayName,
          avatarPath: path,
        );
      });
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _editName() async {
    final controller =
        TextEditingController(text: _profile?.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    try {
      await _service.updateDisplayName(name);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _confirmDelete() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Delete your account?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently deletes your profile and every memory, photo, video and voice note. It cannot be undone.',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 14),
              const Text('Type DELETE to confirm:',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setLocal(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: controller.text.trim().toUpperCase() == 'DELETE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Delete forever',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _service.deleteAccount();
      // Success: the sign-out event sends the app back to the login screen.
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showSnack(context, friendlyError(e));
    }
  }

  Future<void> _logout() async {
    await _auth.signOut(); // root gate returns to the login screen
  }

  void _info(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title),
        content: Text(body, style: const TextStyle(height: 1.45)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _profile == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accentLight));
    }
    if (_error != null && _profile == null) {
      return Center(child: ErrorView(message: _error!, onRetry: _load));
    }

    final email = _auth.currentUser?.email ?? '';
    final name = (_profile?.displayName?.trim().isNotEmpty ?? false)
        ? _profile!.displayName!
        : (email.contains('@') ? email.split('@').first : 'You');
    final username = _profile?.username;

    return Stack(children: [
      SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: memoryStore,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Center(
              child: GestureDetector(
                onTap: _uploading ? null : _changeAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.accent, width: 2),
                      ),
                      child: ClipOval(
                        child: _uploading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.accentLight))
                            : PrivateImage(
                                path: _profile?.avatarPath,
                                bucket: SupabaseConfig.avatarBucket,
                                cacheWidth: 300,
                                fallback: Container(
                                  color: AppColors.elevated,
                                  alignment: Alignment.center,
                                  child: Text(
                                    (name.isEmpty ? '?' : name[0].toUpperCase()),
                                    style: const TextStyle(
                                        fontSize: 44,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accentLight),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppColors.accent),
                        child: const Icon(Icons.edit,
                            size: 16, color: AppColors.onAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w600)),
            if (username != null && username.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('@$username',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 22),

            // Stats
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  _Stat(
                      value: '${memoryStore.memories.length}',
                      label: 'MEMORIES'),
                  const _StatDivider(),
                  _Stat(value: '${memoryStore.placeCount}', label: 'PLACES'),
                  const _StatDivider(),
                  _Stat(
                      value: '${memoryStore.favoriteCount}',
                      label: 'FAVORITES'),
                ],
              ),
            ),
            const SizedBox(height: 18),

            _Row(
                icon: Icons.person_outline,
                label: 'Edit display name',
                onTap: _editName),
            _Row(
                icon: Icons.place_outlined,
                label: 'Location permissions',
                onTap: () => LocationService().openSettings()),
            _Row(
                icon: Icons.lock_outline,
                label: 'Privacy',
                onTap: () => _info('Privacy',
                    'Your memories are private Only you can see your photos, videos and voice notes.They are stored in private storage and protected by your account.')),
            _Row(
                icon: Icons.info_outline,
                label: 'About Memories',
                onTap: () => _info('About Memories',
                    'Memories → your life, mapped\nA private, location-based memory journal.')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.line),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_forever_outlined,
                  size: 18, color: AppColors.textSecondary),
              label: const Text('Delete account',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 4),
            Text(email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
      ),
      if (_deleting)
        Positioned.fill(
          child: Container(
            color: const Color(0xE6090B12),
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.accentLight),
                SizedBox(height: 16),
                Text('Deleting your account…',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.line);
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      index: 3,
      dy: 14,
      child: Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.accentLight),
                const SizedBox(width: 14),
                Expanded(child: Text(label)),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}
