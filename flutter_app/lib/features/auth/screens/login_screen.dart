// lib/features/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authNotifierProvider.notifier).signIn(
            _emailController.text,
            _passwordController.text,
          );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (user.isNgo && user.isPending) {
        _showPendingApprovalDialog();
        return;
      }

      if (user.isAdmin) {
        context.go('/admin/dashboard');
      } else if (user.isNgo) {
        context.go('/ngo/dashboard');
      } else {
        context.go('/citizen/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        final msg = e.toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('AppException: ', '');
        _errorMessage = msg;
      });

      if (e.toString().contains('pending') || e.toString().contains('verification')) {
        _showPendingApprovalDialog();
      }
    }
  }

  void _showPendingApprovalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.hourglass_top, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Verification Pending'),
          ],
        ),
        content: const Text(
          'Your NGO registration has been received and is currently awaiting verification by a PAW-AID administrator.\n\nOnce your animal welfare credentials are confirmed, you will receive full access to the dispatcher rescue queue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    bool isResetting = false;
    String? resetError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Reset Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your registered email address and we will send you a password reset link.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                if (resetError != null) ...[
                  Text(
                    resetError!,
                    style: const TextStyle(color: AppColors.critical, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isResetting
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty) {
                          setDialogState(() => resetError = 'Please enter your email address.');
                          return;
                        }
                        setDialogState(() {
                          isResetting = true;
                          resetError = null;
                        });
                        try {
                          await ref.read(authNotifierProvider.notifier).sendPasswordReset(email);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Password reset instructions sent to $email'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() {
                            isResetting = false;
                            resetError = e.toString()
                                .replaceFirst('Exception: ', '')
                                .replaceFirst('AppException: ', '');
                          });
                        }
                      },
                child: isResetting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send Reset Link'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleBypassSignIn(String role) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).signInWithRole(role);
    } catch (_) {}

    if (mounted) {
      switch (role) {
        case 'admin':
          context.go('/admin/dashboard');
          break;
        case 'ngo_staff':
          context.go('/ngo/dashboard');
          break;
        default:
          context.go('/citizen/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App branding
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 2),
                          ),
                          child: const Icon(
                            Icons.pets,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'PAW-AID',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Emergency Animal Rescue Network',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
                  const SizedBox(height: 48),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.critical.withOpacity(0.15),
                        border: Border.all(color: AppColors.critical.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.critical),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.critical, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ).animate().shake(),

                  // Email input
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'Enter your email',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSignIn(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      hintText: 'Enter your password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _showForgotPasswordDialog,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sign In button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('SIGN IN'),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '⚡ 1-TAP DEMO ACCOUNTS',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildQuickLoginCard(
                    context: context,
                    role: 'citizen',
                    title: 'Citizen Account',
                    name: 'Priya Ramesh (citizen@pawaid.com)',
                    subtitle: 'Report animal distress, AI injury analysis & track rescue',
                    icon: Icons.person,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),

                  _buildQuickLoginCard(
                    context: context,
                    role: 'ngo_staff',
                    title: 'NGO Dispatcher Account',
                    name: 'CARF Chennai (ngo@pawaid.com)',
                    subtitle: 'Manage rescue queue, accept cases & update care stages',
                    icon: Icons.home_work,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 10),

                  _buildQuickLoginCard(
                    context: context,
                    role: 'admin',
                    title: 'Platform Administrator',
                    name: 'System Admin (admin@pawaid.com)',
                    subtitle: 'Approve pending NGOs, view heatmaps & city analytics',
                    icon: Icons.admin_panel_settings,
                    color: AppColors.info,
                  ),
                  const SizedBox(height: 20),

                  // Or divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textHint,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Guest Mode CTA
                  OutlinedButton.icon(
                    onPressed: () => context.push('/report'),
                    icon: const Icon(Icons.report_problem_outlined, color: AppColors.primary),
                    label: const Text('REPORT INJURED ANIMAL (GUEST)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Register links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: const Text('Register as Citizen'),
                      ),
                      TextButton(
                        onPressed: () => context.push('/ngo-register'),
                        child: const Text('Register your NGO'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLoginCard({
    required BuildContext context,
    required String role,
    required String title,
    required String name,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: _isLoading ? null : () => _handleBypassSignIn(role),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'TAP TO ENTER',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
