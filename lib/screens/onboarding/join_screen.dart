import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firebase_app_state.dart';
import '../../models/partner.dart';
import '../../theme/app_theme.dart';
import '../main/home_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _inviteCodeController = TextEditingController();
  final _nameController = TextEditingController();
  String _gender = '';
  bool _isLoading = false;

  Future<void> _joinPartner() async {
    if (_inviteCodeController.text.isEmpty || 
        _nameController.text.isEmpty || 
        _gender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final partner = Partner(
      id: 'B', // Second partner is always B
      name: _nameController.text,
      gender: _gender,
      relationshipGoals: [], // Will be filled during shared onboarding
      currentChallenges: [], // Will be filled during shared onboarding
    );

    final result = await context.read<FirebaseAppState>().joinWithInviteCode(
      _inviteCodeController.text.toUpperCase(),
      partner,
    );

    setState(() => _isLoading = false);

    if (result.isSuccess && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Your Partner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.gradientStart,
              AppTheme.gradientEnd,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Join your relationship space',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the invite code your partner shared with you',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            
            // Invite code field
            TextFormField(
              controller: _inviteCodeController,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                hintText: 'Enter 6-character code',
                prefixIcon: Icon(Icons.vpn_key),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              onChanged: (value) {
                _inviteCodeController.text = value.toUpperCase();
                _inviteCodeController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _inviteCodeController.text.length),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your first name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Gender selection
            Text(
              'Gender',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ['Male', 'Female', 'Other'].map((gender) {
                return ChoiceChip(
                  label: Text(gender),
                  selected: _gender == gender,
                  onSelected: (selected) {
                    setState(() => _gender = selected ? gender : '');
                  },
                );
              }).toList(),
            ),
            
            const SizedBox(height: 32),
            
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your partner will have shared a 6-character invite code with you via text, email, or another messaging app.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Join button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _joinPartner,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join Relationship Space'),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Back to welcome
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Don\'t have a code? Start your own'),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}