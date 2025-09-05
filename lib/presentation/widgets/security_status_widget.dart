import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/security_service.dart';
import '../providers/locale_provider.dart';

class SecurityStatusWidget extends StatelessWidget {
  final bool showDetails;
  final bool isCompact;
  
  const SecurityStatusWidget({
    super.key,
    this.showDetails = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final securityService = SecurityService();
    final securityStatus = securityService.getSecurityStatus();
    
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        if (isCompact) {
          return _buildCompactWidget(context, securityStatus, localeProvider);
        }
        return _buildFullWidget(context, securityStatus, localeProvider);
      },
    );
  }
  
  Widget _buildCompactWidget(
    BuildContext context, 
    Map<String, dynamic> status, 
    LocaleProvider localeProvider
  ) {
    final isSecure = status['isSecurityEnabled'] as bool;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSecure 
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSecure ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSecure ? Icons.security : Icons.warning,
            size: 16,
            color: isSecure ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isSecure 
                ? (localeProvider.isEnglish ? 'Secure' : 'Güvenli')
                : (localeProvider.isEnglish ? 'Warning' : 'Uyarı'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSecure ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFullWidget(
    BuildContext context, 
    Map<String, dynamic> status, 
    LocaleProvider localeProvider
  ) {
    final isSecure = status['isSecurityEnabled'] as bool;
    final securityService = SecurityService();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSecure ? Icons.security : Icons.warning,
                  color: isSecure ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  localeProvider.isEnglish ? 'Security Status' : 'Güvenlik Durumu',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Security status indicator
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSecure 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSecure ? Colors.green : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSecure ? Icons.check_circle : Icons.warning_amber,
                    color: isSecure ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      securityService.getSecurityWarningMessage(
                        localeProvider.locale.languageCode
                      ),
                      style: TextStyle(
                        color: isSecure ? Colors.green.shade700 : Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            if (showDetails) ...
            [
              const SizedBox(height: 16),
              Text(
                localeProvider.isEnglish ? 'Security Features:' : 'Güvenlik Özellikleri:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              
              // Security features list
              ...securityService.getSecurityFeatures(
                localeProvider.locale.languageCode
              ).map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: isSecure ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          color: isSecure ? Colors.green.shade700 : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
              
              const SizedBox(height: 16),
              
              // Technical details
              ExpansionTile(
                title: Text(
                  localeProvider.isEnglish ? 'Technical Details' : 'Teknik Detaylar',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: status.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                entry.value.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: entry.value == true 
                                      ? Colors.green 
                                      : entry.value == false 
                                          ? Colors.red 
                                          : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SecurityWarningDialog extends StatelessWidget {
  const SecurityWarningDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        final securityService = SecurityService();
        
        return AlertDialog(
          icon: const Icon(
            Icons.security,
            color: Colors.green,
            size: 48,
          ),
          title: Text(
            localeProvider.isEnglish ? 'Security Enabled' : 'Güvenlik Etkinleştirildi',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                securityService.getSecurityWarningMessage(
                  localeProvider.locale.languageCode
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ...securityService.getSecurityFeatures(
                localeProvider.locale.languageCode
              ).map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                localeProvider.isEnglish ? 'OK' : 'Tamam',
              ),
            ),
          ],
        );
      },
    );
  }
}