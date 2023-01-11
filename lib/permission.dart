import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'homePage.dart';

enum PermissionState {
  noStoragePermission, // Permission denied, but not forever
  noStoragePermissionPermanent, // Permission denied forever
  grantedPermission // Permission granted
}

class AppPermission extends StatefulWidget {
  const AppPermission({Key? key}) : super(key: key);

  @override
  State<AppPermission> createState() => _AppPermissionState();
}

class _AppPermissionState extends State<AppPermission>
    with WidgetsBindingObserver {
  Future<PermissionState> _storagePermission =
      Future.value(PermissionState.noStoragePermission);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    _checkStoragePermission();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final status = await Permission.storage.status;
      if (status == PermissionStatus.granted &&
          _storagePermission !=
              Future.value(PermissionState.grantedPermission)) {
        setState(() {
          _storagePermission = Future.value(PermissionState.grantedPermission);
        });
      } else if (status == PermissionStatus.denied &&
          _storagePermission ==
              Future.value(PermissionState.grantedPermission)) {
        _storagePermission = Future.value(PermissionState.noStoragePermission);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkStoragePermission() async {
    final status = await Permission.storage.status;
    if (status == PermissionStatus.granted) {
      setState(() {
        _storagePermission = Future.value(PermissionState.grantedPermission);
      });
    } else {
      final result = await Permission.storage.request();
      if (result == PermissionStatus.granted) {
        setState(() {
          _storagePermission = Future.value(PermissionState.grantedPermission);
        });
      } else if (result == PermissionStatus.permanentlyDenied) {
        setState(() {
          _storagePermission =
              Future.value(PermissionState.noStoragePermissionPermanent);
        });
      } else {
        setState(() {
          _storagePermission =
              Future.value(PermissionState.noStoragePermission);
        });
      }
    }
  }

  Future<void> _showOpenAppSettingButton() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("Please allow app permission for storage"),
          actions: <Widget>[
            TextButton(
              child: const Text("Open App Settings"),
              onPressed: () async {
                await openAppSettings();
              },
            ),
            TextButton(
              child: const Text("Exit"),
              onPressed: () {
                SystemNavigator.pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _storagePermission,
      builder: (context, status) {
        if (status.connectionState == ConnectionState.done) {
          if (status.hasData) {
            if (status.data == PermissionState.grantedPermission) {
              return HomePage();
            } else if (status.data == PermissionState.noStoragePermission) {
              return HandlePermissions(
                  isPermanent: false, onPressed: _checkStoragePermission);
            } else if (status.data ==
                PermissionState.noStoragePermissionPermanent) {
              return HandlePermissions(
                  isPermanent: true, onPressed: _checkStoragePermission);
            } else {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(
                        height: 20,
                      ),
                      Text("Waiting for storage permission"),
                    ],
                  ),
                ),
              );
            }
          } else {
            return const Scaffold(
                body: Center(
              child: Text(
                  'Something went wrong.. Please uninstall and Install Again'),
            ));
          }
        } else {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}

class HandlePermissions extends StatelessWidget {
  final bool isPermanent;
  final VoidCallback onPressed;

  const HandlePermissions({
    Key? key,
    required this.isPermanent,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Handle permissions'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.only(
                left: 16.0,
                top: 24.0,
                right: 16.0,
              ),
              child: Text(
                'Storage access permission',
                style: Theme.of(context).textTheme.headline6,
              ),
            ),
            Container(
              padding: const EdgeInsets.only(
                left: 16.0,
                top: 24.0,
                right: 16.0,
              ),
              child: const Text(
                'We need to request your permission to access local storage in order to load the app.',
                textAlign: TextAlign.center,
              ),
            ),
            if (isPermanent)
              Container(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  top: 24.0,
                  right: 16.0,
                ),
                child: const Text(
                  'You need to give this permission from the system settings.',
                  textAlign: TextAlign.center,
                ),
              ),
            Container(
              padding: const EdgeInsets.only(
                  left: 16.0, top: 24.0, right: 16.0, bottom: 24.0),
              child: ElevatedButton(
                child: Text(isPermanent ? 'Open settings' : 'Allow access'),
                onPressed: () => isPermanent ? openAppSettings() : onPressed(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
