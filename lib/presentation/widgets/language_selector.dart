import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

class LanguageSelector extends StatelessWidget {
  final bool showTitle;
  final bool isCompact;
  
  const LanguageSelector({
    super.key,
    this.showTitle = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        if (isCompact) {
          return _buildCompactSelector(context, localeProvider);
        }
        return _buildFullSelector(context, localeProvider);
      },
    );
  }
  
  Widget _buildCompactSelector(BuildContext context, LocaleProvider localeProvider) {
    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.language,
            size: 20,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            localeProvider.locale.languageCode.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
      onSelected: (String languageCode) {
        localeProvider.setLocale(Locale(languageCode, ''));
      },
      itemBuilder: (BuildContext context) {
        return localeProvider.localeDisplayNames.entries.map((entry) {
          return PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                Icon(
                  localeProvider.locale.languageCode == entry.key
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: localeProvider.locale.languageCode == entry.key
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(entry.value),
              ],
            ),
          );
        }).toList();
      },
    );
  }
  
  Widget _buildFullSelector(BuildContext context, LocaleProvider localeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...
        [
          Text(
            _getLocalizedText(context, 'language'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: localeProvider.localeDisplayNames.entries.map((entry) {
              final isSelected = localeProvider.locale.languageCode == entry.key;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                ),
                title: Text(
                  entry.value,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Theme.of(context).primaryColor : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.done,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  localeProvider.setLocale(Locale(entry.key, ''));
                  _showLanguageChangedSnackBar(context);
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  
  void _showLanguageChangedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getLocalizedText(context, 'languageChanged')),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  String _getLocalizedText(BuildContext context, String key) {
    // Temporary implementation until AppLocalizations is generated
    final localeProvider = context.read<LocaleProvider>();
    final isEnglish = localeProvider.isEnglish;
    
    switch (key) {
      case 'language':
        return isEnglish ? 'Language' : 'Dil';
      case 'languageChanged':
        return isEnglish ? 'Language changed successfully' : 'Dil başarıyla değiştirildi';
      default:
        return key;
    }
  }
}

class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return IconButton(
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, size: 20),
              const SizedBox(width: 4),
              Text(
                localeProvider.locale.languageCode.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          onPressed: () {
            localeProvider.toggleLocale();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localeProvider.isEnglish 
                      ? 'Language changed to English'
                      : 'Dil Türkçe olarak değiştirildi',
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          tooltip: localeProvider.isEnglish ? 'Switch to Turkish' : 'İngilizce\'ye geç',
        );
      },
    );
  }
}