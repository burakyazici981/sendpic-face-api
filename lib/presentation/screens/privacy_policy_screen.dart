import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSection(
              'Data Collection & Storage',
              [
                'We collect only essential information needed for app functionality',
                'User profiles (name, email, profile picture) are stored securely in our database',
                'Messages and posts metadata are stored for real-time functionality',
                'Face recognition data is processed locally and stored encrypted',
                'We DO NOT store actual photos or videos for security reasons',
                'All data is encrypted both in transit and at rest',
              ],
            ),
            _buildSection(
              'What We Don\'t Store',
              [
                'Photos and videos you send are NOT permanently stored',
                'Media files are temporarily processed and immediately deleted',
                'We cannot access your sent or received media content',
                'Face recognition happens locally on your device',
                'No biometric data leaves your device',
              ],
            ),
            _buildSection(
              'Security Measures',
              [
                'End-to-end encryption for all communications',
                'Screenshot and screen recording protection',
                'Secure token-based authentication',
                'Regular security audits and updates',
                'No third-party access to your personal data',
                'Automatic logout on suspicious activity',
              ],
            ),
            _buildSection(
              'Face Recognition Privacy',
              [
                'Face detection and recognition happens entirely on your device',
                'No facial data is transmitted to our servers',
                'Face encodings are stored locally and encrypted',
                'You can delete all face data at any time',
                'Face recognition is used only for content filtering',
                'No facial recognition data is shared with third parties',
              ],
            ),
            _buildSection(
              'Token System',
              [
                'Tokens are virtual currency for app functionality',
                'Payment processing is handled by Apple/Google (secure)',
                'We don\'t store payment information',
                'Token transactions are logged for account management',
                'Unused tokens don\'t expire',
                'Refunds follow platform policies (App Store/Play Store)',
              ],
            ),
            _buildSection(
              'Real-time Features',
              [
                'Real-time messaging uses secure WebSocket connections',
                'Online status is shared only with accepted friends',
                'Message delivery confirmations are temporary',
                'No message content is analyzed or stored permanently',
                'Connection logs are kept for 30 days maximum',
              ],
            ),
            _buildSection(
              'Data Sharing',
              [
                'We DO NOT sell your personal information',
                'No data sharing with advertising companies',
                'Anonymous usage statistics may be collected for app improvement',
                'Legal compliance may require data disclosure (rare cases)',
                'You can request complete data deletion at any time',
              ],
            ),
            _buildSection(
              'Your Rights',
              [
                'Access all your stored data',
                'Request data correction or deletion',
                'Export your data in standard formats',
                'Opt-out of optional data collection',
                'Disable face recognition features',
                'Delete your account and all associated data',
              ],
            ),
            _buildSection(
              'Children\'s Privacy',
              [
                'This app is not intended for users under 13',
                'We don\'t knowingly collect data from children',
                'Parental consent required for users 13-17',
                'Additional protections for younger users',
                'Report underage users to support team',
              ],
            ),
            _buildSection(
              'Updates & Changes',
              [
                'Privacy policy updates will be notified in-app',
                'Major changes require explicit consent',
                'Version history available on request',
                'Continued use implies acceptance of updates',
                'You can review changes before accepting',
              ],
            ),
            _buildContactSection(),
            const SizedBox(height: 32),
            _buildLastUpdated(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF74B9FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                color: Colors.white,
                size: 32,
              ),
              SizedBox(width: 12),
              Text(
                'Your Privacy Matters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'We are committed to protecting your privacy and ensuring the security of your personal information. This policy explains how we handle your data.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> points) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF6C5CE7),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    point,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.contact_support,
                color: Color(0xFF6C5CE7),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Contact Us',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'If you have any questions about this Privacy Policy or our data practices, please contact us:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildContactItem(Icons.email, 'Email', 'privacy@sendpic.app'),
          _buildContactItem(Icons.language, 'Website', 'www.sendpic.app/privacy'),
          _buildContactItem(Icons.location_on, 'Address', 'SendPic Inc.\n123 Privacy Street\nSecure City, SC 12345'),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: const Color(0xFF6C5CE7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.update,
            color: Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            'Last updated: ',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            DateTime.now().toString().split(' ')[0],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}