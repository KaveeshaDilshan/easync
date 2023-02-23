import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:ping_discover_network_forked/ping_discover_network_forked.dart';
import 'detailfolder.dart';
import 'package:file_picker/file_picker.dart';

import 'linearProgressBar.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool deviceConnected = false;
  ServerSocket? serverObject;
  Socket? clientObject;
  bool syncClosed = true;
  double progressBarSize = 0.0;
  bool isFileCopying = false;
  Future<String> createFolderInAppDocDir(String folderName) async {
    final Directory appDocDirFolder =
        Directory('/storage/emulated/0/Easync/$folderName/');
    if (await appDocDirFolder.exists()) {
      //if folder already exists return path
      return appDocDirFolder.path;
    } else {
      //if folder not exists create folder and then return its path
      final Directory appDocDirNewFolder =
          await appDocDirFolder.create(recursive: true);
      return appDocDirNewFolder.path;
    }
  }

  callFolderCreationMethod(String folderInAppDocDir) async {
    // ignore: unused_local_variable
    String actualFileName = await createFolderInAppDocDir(folderInAppDocDir);
    setState(() {});
  }

  final folderController = TextEditingController();
  late String nameOfFolder;
  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            children: const [
              Text(
                'ADD FOLDER',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Type a folder name to add',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return TextField(
                controller: folderController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Enter folder name',
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Colors.grey,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 15.0,
                    horizontal: 10.0,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    nameOfFolder = folderController.text;
                  });
                },
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'Add',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                if (nameOfFolder != null) {
                  await callFolderCreationMethod(nameOfFolder);
                  getDir();
                  setState(() {
                    folderController.clear();
                    nameOfFolder = "";
                  });
                  Navigator.of(context).pop();
                }
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  late List<FileSystemEntity> _folders;
  Future<void> getDir() async {
    await createRootFolder();
    String pdfDirectory = '/storage/emulated/0/Easync/';
    final myDir = Directory(pdfDirectory);
    setState(() {
      _folders = myDir.listSync(recursive: false, followLinks: false);
    });
  }

  Future<void> _showDeleteDialog(int index) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Are you sure you want to delete this folder?',
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                await _folders[index].delete(recursive: true);
                await getDir();
                await Future.delayed(const Duration(milliseconds: 100));
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    _folders = [];
    getDir();
    super.initState();
  }

  Future<void> createRootFolder() async {
    // Create root directory for app
    final Directory rootDirectory = Directory('/storage/emulated/0/Easync/');
    if (!await rootDirectory.exists()) {
      await rootDirectory.create(recursive: true);
    }
  }

  Future<String> checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.wifi) {
      return "wifi";
    } else {
      return "none";
    }
  }

  Future<String> getSubnet() async {
    for (var interface in await NetworkInterface.list()) {
      if (interface.name == 'wlan0' || interface.name == 'swlan0') {
        for (var addr in interface.addresses) {
          if (addr.address.startsWith('192.168.')) {
            return addr.address.split('.').sublist(0, 3).join('.');
          }
        }
      }
    }
    return '192.169.5';
  }

  Future<String> getConnectedDeviceIp() async {
    var subnet = await getSubnet();
    const port = 1234;
    final stream = NetworkAnalyzer.discover2(
      subnet,
      port,
      timeout: const Duration(seconds: 5),
    );
    String serverIP = '192.169.5.5';
    stream.listen((NetworkAddress addr) {
      if (addr.exists) {
        serverIP = addr.ip;
      }
    });
    return serverIP;
  }

  final GlobalKey<State<StatefulWidget>> _dialogKey =
      GlobalKey<State<StatefulWidget>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Easync Folders"),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_rounded),
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles();
              if (result == null) return;
              final file = result.files.first;
              await saveFilePermanently(file);
            },
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded),
            onPressed: () {
              _showMyDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              setState(() {
                syncClosed = false;
              });
              showDialog(
                barrierDismissible: false,
                context: context,
                builder: (BuildContext context) {
                  return StatefulBuilder(
                    key: _dialogKey,
                    builder: (context, setState) {
                      if (deviceConnected) {
                        Future.delayed(const Duration(milliseconds: 1500));
                        Navigator.of(context).pop();
                      }
                      return Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 16.0,
                          ),
                          child: Container(
                            width: double.infinity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Make sure both devices are connected to the same local Wi-Fi network',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                deviceConnected
                                    ? Column(
                                        children: const [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 40,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Devices are connected!',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: const [
                                          SizedBox(
                                            height: 40,
                                            width: 40,
                                            child: CircularProgressIndicator(),
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'Waiting for connecting devices...',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      syncClosed = true;
                                    });
                                    if (serverObject != null) {
                                      serverObject?.close();
                                      setState(() {
                                        serverObject = null;
                                      });
                                    }
                                    if (clientObject != null) {
                                      clientObject?.close();
                                      setState(() {
                                        clientObject = null;
                                      });
                                    }
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );

              while (!deviceConnected && !syncClosed) {
                String connectivityState = await checkConnectivity();
                String subnet = await getSubnet();
                if (connectivityState == "wifi" &&
                    subnet.startsWith('192.168.')) {
                  for (int i = 1; i <= 255; i++) {
                    // print('$subnet.$i');
                    await client("$subnet.$i", 1234, 5046,
                        "/storage/emulated/0/Easync/");
                    await Future.delayed(const Duration(milliseconds: 110));
                    if (deviceConnected || syncClosed) break;
                  }
                } else {
                  if (serverObject == null) {
                    await server(1234, 5046);
                  }
                  await Future.delayed(const Duration(seconds: 1));
                }

                if (serverObject != null && !deviceConnected) {
                  serverObject?.close();
                  setState(() {
                    serverObject = null;
                  });
                }
                if (clientObject != null && !deviceConnected) {
                  clientObject?.close();
                  setState(() {
                    clientObject = null;
                  });
                }
              }
            },
          ),
        ],
        bottom: (deviceConnected || isFileCopying)
            ? MyLinearProgressIndicator(
                backgroundColor: Colors.blue,
                value: progressBarSize,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              )
            : null,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 25,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemBuilder: (context, index) {
          return Material(
            elevation: 6.0,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FutureBuilder(
                          future: getFileType(_folders[index]),
                          builder: (ctx, snapshot) {
                            if (snapshot.hasData) {
                              FileStat f = snapshot.data as FileStat;
                              if (f.type.toString().contains("file")) {
                                return InkWell(
                                  onTap: () {
                                    File file = File(_folders[index].path);
                                    openFile(file);
                                  },
                                  child: const Icon(
                                    Icons.file_copy_outlined,
                                    size: 100,
                                    color: Colors.orange,
                                  ),
                                );
                              } else {
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(context,
                                        MaterialPageRoute(builder: (builder) {
                                      return InnerFolder(
                                          filesPath: _folders[index].path);
                                    }));
                                  },
                                  child: const Icon(
                                    Icons.folder,
                                    size: 100,
                                    color: Colors.orange,
                                  ),
                                );
                              }
                            }
                            return const Icon(
                              Icons.file_copy_outlined,
                              size: 100,
                              color: Colors.orange,
                            );
                          }),
                      Text(
                        _folders[index].path.split('/').last,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () {
                      _showDeleteDialog(index);
                    },
                    child: const Icon(
                      Icons.delete,
                      color: Colors.grey,
                    ),
                  ),
                )
              ],
            ),
          );
        },
        itemCount: _folders.length,
      ),
    );
  }

  // Future<void> saveFilePermanently(PlatformFile file) async {
  //   final newFile = File('/storage/emulated/0/Easync/${file.name}');
  //   await File(file.path!).copy(newFile.path);
  //   getDir();
  // }

  Future<void> saveFilePermanently(PlatformFile file) async {
    setState(() {
      isFileCopying = true;
    });
    final newFile = File('/storage/emulated/0/Easync/${file.name}');

    final oldFile = File(file.path!);
    final oldFileLength = await oldFile.length();

    final newFileSink = newFile.openWrite();
    final oldFileStream = oldFile.openRead();

    int bytesWritten = 0;
    var completer = Completer<void>();
    await for (final data in oldFileStream) {
      bytesWritten += data.length;
      newFileSink.add(data);
      final progress = bytesWritten / oldFileLength;
      setState(() {
        progressBarSize = progress;
      });
      print('Progress: ${progress}');
      if (progress >= 1.0) {
        completer.complete();
      }
    }
    await completer.future;
    getDir();
    await newFileSink.close();
    setState(() {
      isFileCopying = false;
    });
  }

  void openFile(File file) {
    OpenFile.open(file.path);
  }

  Future getFileType(file) {
    return file.stat();
  }

  Future<void> server(int msgServerPort, int fileServerPort) async {
    // Listen for incoming connections on port 1234
    ServerSocket.bind(InternetAddress.anyIPv4, msgServerPort)
        .then((ServerSocket server) async {
      print('Server started');
      setState(() {
        serverObject = server;
      });
      // Wait for clients to connect
      server.listen((Socket socket) {
        setState(() {
          deviceConnected = true;
          _dialogKey.currentState?.setState(() {});
        });

        // Read messages from the client
        utf8.decoder.bind(socket).listen((String data) async {
          Map<String, dynamic> jsonMap = json.decode(data);
          // Handle different types of messages
          switch (jsonMap["route"]) {
            case 'SYNC':
              String folderPath = jsonMap["folderPath"];
              Directory folder = Directory(folderPath);
              var filePaths = <String>[];
              await folder.list(recursive: true).forEach((element) {
                if (element is File) {
                  filePaths.add(element.path);
                }
              });
              final jsonData = {
                "route": 'SYNC',
                "folderPath": folderPath,
                "files": filePaths,
              };
              final jsonString = json.encode(jsonData);
              socket.write(jsonString);
              break;
            case 'FILE':
              // Receive a file from the client
              String filePath = jsonMap["filePath"];
              int fileSize = jsonMap["fileSize"];
              await receiveFile(filePath, fileServerPort, fileSize);
              break;
            case 'REQUEST':
              List<dynamic> requestedFiles = jsonMap["files"];
              String folderPath = jsonMap["folderPath"];
              Directory folder = Directory(folderPath);
              await for (FileSystemEntity entity
                  in folder.list(recursive: true)) {
                String filePath = entity.path;
                if ((entity is File) && (requestedFiles.contains(filePath))) {
                  // Send the file to the server
                  final jsonData = {
                    "route": 'RESPOND',
                    "filePath": filePath,
                    "fileSize": entity.lengthSync()
                  };
                  final jsonString = json.encode(jsonData);
                  socket.write(jsonString);
                  await Future.delayed(const Duration(seconds: 1));
                  var completer = Completer<void>();
                  var response = await sendFile(
                      filePath, socket.remoteAddress.address, fileServerPort);
                  if (response.statusCode == 200) {
                    completer.complete();
                  }
                  await completer.future;
                }
              }
              final jsonData = {
                "route": 'CLOSE',
              };
              socket.write(json.encode(jsonData));
              await Future.delayed(const Duration(seconds: 1));
              server.close();
              setState(() {
                serverObject = null;
                deviceConnected = false;
                syncClosed = true;
              });
              break;
            case 'CLOSE':
              // Close the connection
              server.close();
              debugPrint('Client disconnected');
              break;
            default:
              debugPrint('Unknown message: $data');
              break;
          }
        });
      });
    });
  }

  Future<void> client(String serverIp, int msgServerPort, int fileServerPort,
      String folderPath) async {
    // Connect to the server
    try {
      Socket.connect(serverIp, msgServerPort).then((Socket socket) {
        setState(() {
          deviceConnected = true;
          clientObject = socket;
          _dialogKey.currentState?.setState(() {});
        });
        // Send a message to the server to indicate that a folder is being synchronized
        final jsonData = {
          "route": 'SYNC',
          "folderPath": folderPath,
        };
        final jsonString = json.encode(jsonData);
        socket.write(jsonString);

        // Wait for the server to acknowledge the synchronization request
        utf8.decoder.bind(socket).listen((String data) async {
          Map<String, dynamic> jsonMap = json.decode(data);
          if (jsonMap['route'] == 'SYNC') {
            String folderPath = jsonMap['folderPath'];
            List<dynamic> files = jsonMap['files'];

            var myFiles = <String>[];
            Directory folder = Directory(folderPath);
            await folder.list(recursive: true).forEach((element) {
              if (element is File) {
                myFiles.add(element.path);
              }
            });

            var requiredFiles = <String>[];
            for (var element in files) {
              if (!myFiles.contains(element)) {
                requiredFiles.add(element);
              }
            }

            // Synchronize the files in the folder
            await for (FileSystemEntity entity
                in folder.list(recursive: true)) {
              String filePath = entity.path;
              if ((entity is File) && !(files.contains(filePath))) {
                // Send the file to the server
                final jsonData = {
                  "route": 'FILE',
                  "filePath": filePath,
                  "fileSize": entity.lengthSync()
                };
                final jsonString = json.encode(jsonData);
                socket.write(jsonString);
                await Future.delayed(const Duration(seconds: 1));
                var completer = Completer<void>();
                var response =
                    await sendFile(filePath, serverIp, fileServerPort);
                if (response.statusCode == 200) {
                  completer.complete();
                }
                await completer.future;
              }
            }
            final jsonData = {
              "route": 'REQUEST',
              "files": requiredFiles,
              "folderPath": folderPath,
            };
            final jsonString = json.encode(jsonData);
            socket.write(jsonString);
          } else if (jsonMap['route'] == "RESPOND") {
            String filePath = jsonMap["filePath"];
            int fileSize = jsonMap["fileSize"];
            await receiveFile(filePath, fileServerPort, fileSize);
          } else if (jsonMap['route'] == "CLOSE") {
            setState(() {
              clientObject = null;
              deviceConnected = false;
              syncClosed = true;
            });
            socket.close();
          } else {
            print('Error synchronizing folder');
          }
        });
      }, onError: (error) {
        // print('Connection error');
      });
    } catch (e) {
      print(e);
    }
  }

  Future<HttpClientResponse> sendFile(
      String filePath, String ipAddress, int port) async {
    var file = File(filePath);
    var openedFile = await file.open(mode: FileMode.read);
    var client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 60);
    client.idleTimeout = const Duration(seconds: 60);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    var request = await client.putUrl(Uri.parse('http://$ipAddress:$port'));
    var fileBytes = await openedFile.read(await openedFile.length());
    await request
        .addStream(Stream.fromIterable([Uint8List.fromList(fileBytes)]));
    var response = await request.close();
    await openedFile.close();
    return response;
  }

  Future<void> receiveFile(String filePath, int port, int fileSize) async {
    var server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      5046,
      shared: true,
    );
    print('Listening on port $port...');
    await for (var request in server) {
      if (request.method == 'PUT') {
        var file = File(filePath);
        if (!file.existsSync()) {
          await file.create(recursive: true);
        }
        var consumer = file.openWrite();
        var completer = Completer<void>();
        var count = 0;
        request.listen((data) {
          count += data.length;
          print('Received $count/$fileSize bytes');
          consumer.add(data);
          if (count == fileSize) {
            setState(() {
              progressBarSize = 0.0;
            });
            completer.complete();
          } else {
            setState(() {
              progressBarSize = count / fileSize;
            });
          }
        }, onDone: () {
          consumer.close();
        }, onError: (error) {
          consumer.close();
          completer.completeError(error);
        });
        await completer.future;
        request.response
          ..statusCode = 200
          ..close();
        print('File saved to $filePath');
        await getDir();
        break;
      } else {
        request.response
          ..statusCode = HttpStatus.methodNotAllowed
          ..write('Unsupported request: ${request.method}.')
          ..close();
      }
    }
    server.close();
  }
}
