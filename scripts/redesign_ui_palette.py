# scripts/redesign_ui_palette.py
import re

files_to_update = {
    # 1. Citizen Dashboard
    "flutter_app/lib/features/citizen/screens/citizen_dashboard_screen.dart": [
        (
            "color: Colors.white,\n                          fontWeight: FontWeight.w800,",
            "color: AppColors.textPrimaryLight,\n                          fontWeight: FontWeight.w800,"
        ),
        (
            "colors: [\n                        AppColors.primary,\n                        Color(0xFFE0531D),\n                      ],",
            "colors: [\n                        AppColors.primary,\n                        AppColors.primaryLight,\n                      ],"
        ),
        (
            "Icon(Icons.report_problem, size: 28, color: Colors.white),",
            "Icon(Icons.report_problem, size: 28, color: AppColors.cream),"
        ),
        (
            "color: Colors.white,\n                            ),",
            "color: AppColors.cream,\n                            ),"
        ),
        (
            "color: Colors.white70, fontSize: 13, height: 1.4",
            "color: AppColors.sand, fontSize: 13, height: 1.4"
        ),
        (
            "backgroundColor: Colors.white,\n                          foregroundColor: AppColors.primary,",
            "backgroundColor: AppColors.cream,\n                          foregroundColor: AppColors.primary,\n                          elevation: 2,"
        )
    ],

    # 2. Citizen Rescue Card
    "flutter_app/lib/features/citizen/widgets/rescue_card.dart": [
        (
            "color: AppColors.surface,\n          borderRadius: BorderRadius.circular(12),\n          border: Border.all(color: AppColors.cardBorder),",
            "color: AppColors.surfaceLight,\n          borderRadius: BorderRadius.circular(14),\n          border: Border.all(color: AppColors.cardBorderLight, width: 1.2),\n          boxShadow: [\n            BoxShadow(\n              color: AppColors.mocha.withOpacity(0.05),\n              blurRadius: 10,\n              offset: const Offset(0, 3),\n            ),\n          ],"
        ),
        (
            "color: Colors.white),\n                ),",
            "color: AppColors.textPrimaryLight),\n                ),"
        ),
        (
            "color: AppColors.textSecondary",
            "color: AppColors.textSecondaryLight"
        ),
        (
            "color: AppColors.textHint",
            "color: AppColors.textHintLight"
        )
    ],

    # 3. Citizen Report Animal Screen
    "flutter_app/lib/features/citizen/screens/report_animal_screen.dart": [
        (
            "color: Colors.white,\n          ),",
            "color: AppColors.textPrimaryLight,\n          ),"
        ),
        (
            "color: AppColors.surface,\n      borderRadius: BorderRadius.circular(12),",
            "color: AppColors.surfaceLight,\n      borderRadius: BorderRadius.circular(14),\n      boxShadow: [\n        BoxShadow(\n          color: AppColors.mocha.withOpacity(0.04),\n          blurRadius: 8,\n          offset: const Offset(0, 2),\n        ),\n      ],"
        ),
        (
            "border: Border.all(color: AppColors.border),",
            "border: Border.all(color: AppColors.borderLight, width: 1.2),"
        ),
        (
            "color: AppColors.textHint",
            "color: AppColors.textHintLight"
        )
    ],

    # 4. Citizen My Reports Screen
    "flutter_app/lib/features/citizen/screens/my_reports_screen.dart": [
        (
            "color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold",
            "color: AppColors.textPrimaryLight, fontSize: 18, fontWeight: FontWeight.bold"
        )
    ],

    # 5. NGO Dashboard Screen
    "flutter_app/lib/features/ngo/screens/ngo_dashboard_screen.dart": [
        (
            "color: Colors.white,\n                        ),",
            "color: AppColors.textPrimaryLight,\n                        ),"
        ),
        (
            "color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold",
            "color: AppColors.textPrimaryLight, fontSize: 24, fontWeight: FontWeight.bold"
        ),
        (
            "color: Colors.white,\n                ),",
            "color: AppColors.white,\n                ),"
        )
    ],

    # 6. NGO Rescue List Tile
    "flutter_app/lib/features/ngo/widgets/rescue_list_tile.dart": [
        (
            "color: AppColors.surface,\n          borderRadius: BorderRadius.circular(12),",
            "color: AppColors.surfaceLight,\n          borderRadius: BorderRadius.circular(14),\n          boxShadow: [\n            BoxShadow(\n              color: AppColors.mocha.withOpacity(0.04),\n              blurRadius: 8,\n              offset: const Offset(0, 2),\n            ),\n          ],"
        ),
        (
            ": AppColors.cardBorder,",
            ": AppColors.cardBorderLight,"
        ),
        (
            "color: Colors.white),\n                ),",
            "color: AppColors.textPrimaryLight),\n                ),"
        ),
        (
            "color: AppColors.textSecondary",
            "color: AppColors.textSecondaryLight"
        ),
        (
            "color: AppColors.textHint",
            "color: AppColors.textHintLight"
        )
    ],

    # 7. Role Switcher Bottom Sheet
    "flutter_app/lib/core/widgets/role_switcher.dart": [
        (
            "backgroundColor: AppColors.surface,",
            "backgroundColor: AppColors.surfaceLight,"
        ),
        (
            "color: Colors.white,\n                      ),",
            "color: AppColors.textPrimaryLight,\n                      ),"
        ),
        (
            "color: isSelected ? color.withOpacity(0.12) : AppColors.surfaceVariant,",
            "color: isSelected ? color.withOpacity(0.12) : AppColors.surfaceVariantLight,"
        ),
        (
            "color: isSelected ? color : AppColors.divider,",
            "color: isSelected ? color : AppColors.borderLight,"
        ),
        (
            "color: Colors.white,\n                        ),",
            "color: AppColors.textPrimaryLight,\n                        ),"
        ),
        (
            "color: AppColors.textSecondary",
            "color: AppColors.textSecondaryLight"
        ),
        (
            "color: AppColors.textHint",
            "color: AppColors.textHintLight"
        )
    ],

    # 8. NGO Case Detail Screen
    "flutter_app/lib/features/ngo/screens/case_detail_screen.dart": [
        (
            "color: Colors.white,\n                            ),",
            "color: AppColors.textPrimaryLight,\n                            ),"
        ),
        (
            "color: Colors.white70",
            "color: AppColors.textSecondaryLight"
        ),
        (
            "color: Colors.white\n                          ),",
            "color: AppColors.textPrimaryLight\n                          ),"
        ),
        (
            "color: Colors.white)),",
            "color: AppColors.textPrimaryLight)),"
        )
    ],

    # 9. Admin Dashboard Screen
    "flutter_app/lib/features/admin/screens/admin_dashboard_screen.dart": [
        (
            "color: Colors.white, fontSize: 14",
            "color: AppColors.textPrimaryLight, fontSize: 14"
        ),
        (
            "color: AppColors.textSecondary",
            "color: AppColors.textSecondaryLight"
        ),
        (
            "color: AppColors.surface,",
            "color: AppColors.surfaceLight,"
        )
    ],

    # 10. AI Report Card
    "flutter_app/lib/features/ngo/widgets/ai_report_card.dart": [
        (
            "color: AppColors.surface,",
            "color: AppColors.surfaceLight,"
        ),
        (
            "border: Border.all(color: AppColors.cardBorder),",
            "border: Border.all(color: AppColors.cardBorderLight, width: 1.2),"
        ),
        (
            "color: AppColors.surfaceVariant,",
            "color: AppColors.surfaceVariantLight,"
        ),
        (
            "color: AppColors.textSecondary",
            "color: AppColors.textSecondaryLight"
        ),
        (
            "color: AppColors.textHint",
            "color: AppColors.textHintLight"
        )
    ]
}

def apply_replacements():
    for filepath, replacements in files_to_update.items():
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()

            normalized_content = content.replace("\r\n", "\n")
            modified_count = 0

            for target, replacement in replacements:
                norm_target = target.replace("\r\n", "\n")
                norm_replacement = replacement.replace("\r\n", "\n")
                if norm_target in normalized_content:
                    normalized_content = normalized_content.replace(norm_target, norm_replacement)
                    modified_count += 1
                else:
                    print(f"  [!] Note: Target snippet not found in {filepath}: {norm_target[:40]}...")

            # Write back preserving system CRLF on Windows
            with open(filepath, "w", encoding="utf-8", newline="\r\n") as f:
                f.write(normalized_content)

            print(f"[OK] {filepath}: applied {modified_count} replacements")
        except Exception as e:
            print(f"[ERR] Failed on {filepath}: {e}")

if __name__ == "__main__":
    apply_replacements()
