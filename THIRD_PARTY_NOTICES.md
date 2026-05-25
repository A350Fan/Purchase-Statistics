# Third-Party Notices

Last reviewed: May 26, 2026

Purchase Statistics is licensed under the GNU General Public License version 3 or later. Third-party dependencies used by the app remain under their own licenses.

This notice is based on `pubspec.lock` and `.flutter-plugins-dependencies` at the review date above. Flutter builds also generate license metadata from package `LICENSE` files. The app exposes those notices under **Settings > Legal > Open source licenses**.

## Key Runtime and Platform Dependencies

This table summarizes the app's direct runtime dependencies and the platform packages that are pulled in for the current Flutter targets. The complete generated package/license list is available through Flutter's license registry in the app.

| Dependency | Version | License observed locally |
| --- | --- | --- |
| Flutter SDK, `flutter_localizations`, and Flutter SDK plugins | 3.44.0 | BSD-style Flutter SDK license |
| `cross_file` | 0.3.5+2 | BSD-style Dart license |
| `dbus` | 0.7.12 | MPL-2.0 |
| `ffi` | 2.2.0 | BSD-style Dart license |
| `file_picker` | 10.3.8 | MIT |
| `flutter_plugin_android_lifecycle` | 2.0.34 | BSD-style Flutter license |
| `flutter_secure_storage` | 10.3.0 | BSD-3-Clause |
| `flutter_secure_storage_darwin` | 0.3.2 | BSD-3-Clause |
| `flutter_secure_storage_linux` | 3.0.1 | BSD-3-Clause |
| `flutter_secure_storage_platform_interface` | 2.0.1 | BSD-3-Clause |
| `flutter_secure_storage_web` | 2.1.1 | BSD-3-Clause |
| `flutter_secure_storage_windows` | 4.1.0 | BSD-3-Clause |
| `jni` | 1.0.0 | BSD-style Dart license |
| `jni_flutter` | 1.0.1 | BSD-style Dart license |
| `objective_c` | 9.3.0 | BSD-style Dart license |
| `package_config` | 2.2.0 | BSD-style Dart license |
| `path` | 1.9.1 | BSD-style Dart license |
| `path_provider` | 2.1.5 | BSD-style Flutter license |
| `path_provider_android` | 2.3.1 | BSD-style Flutter license |
| `path_provider_foundation` | 2.6.0 | BSD-style Flutter license |
| `path_provider_linux` | 2.2.1 | BSD-style Flutter license |
| `path_provider_platform_interface` | 2.1.2 | BSD-style Flutter license |
| `path_provider_windows` | 2.3.0 | BSD-style Flutter license |
| `plugin_platform_interface` | 2.1.8 | BSD-style Flutter license |
| `sqflite` | 2.4.2+1 | BSD-2-Clause |
| `sqflite_android` | 2.4.2+3 | BSD-2-Clause |
| `sqflite_common` | 2.5.8 | BSD-2-Clause |
| `sqflite_common_ffi` | 2.4.0+3 | BSD-2-Clause |
| `sqflite_darwin` | 2.4.2 | BSD-2-Clause |
| `sqflite_platform_interface` | 2.4.0 | BSD-2-Clause |
| `sqlite3` | 3.3.1 | MIT |
| `synchronized` | 3.4.0+1 | MIT |
| `web` | 1.1.1 | BSD-style Dart license |
| `win32` | 5.15.0 | BSD-style Dart license |
| `xdg_directories` | 1.1.0 | BSD-style Flutter license |

No GPL-incompatible license was found among the locally checked app runtime and platform packages listed above. MIT, BSD-style, Apache-2.0, and MPL-2.0 dependencies can be distributed with a GPLv3-or-later application when their copyright and license notices are preserved and the respective license conditions are followed.

## Development-Only Dependencies

| Dependency | Version | License observed locally |
| --- | --- | --- |
| `flutter_launcher_icons` | 0.14.4 | MIT |
| `flutter_lints` | 6.0.0 | BSD-style Flutter license |
| `flutter_test` | 3.44.0 | BSD-style Flutter SDK license |

Development-only dependencies are not intended to be shipped as app runtime code.

## Distribution Notes

When distributing source code, keep `LICENSE`, `README.md`, `CONTRIBUTING.md`, this file, and the package lock/configuration files available.

When distributing binaries, provide the corresponding source code for the GPL-covered app and include third-party notices generated from the dependency license files. For Flutter builds, keep the generated license notices available through the app's open-source licenses screen or include equivalent notice files with the release package.
