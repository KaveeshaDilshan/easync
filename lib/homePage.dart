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
import 'dart:math' as math;

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool deviceConnected = false;
  ServerSocket? serverObject;
  Socket? clientObject;
  bool syncClosed = true;
  Future<String> createFolderInAppDocDir(String folderName) async {
    //Get this App Document Directory
    //final Directory? _appDocDir = await getExternalStorageDirectory();
    //App Document Directory + folder name
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
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            children: const [
              Text(
                'ADD FOLDER',
                textAlign: TextAlign.left,
              ),
              Text(
                'Type a folder name to add',
                style: TextStyle(
                  fontSize: 14,
                ),
              )
            ],
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return TextField(
                controller: folderController,
                autofocus: true,
                decoration:
                    const InputDecoration(hintText: 'Enter folder name'),
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
                'No',
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
    // final directory = await getExternalStorageDirectory();
    // final dir = directory?.path;
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
            'Are you sure to delete this folder?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Yes'),
              onPressed: () async {
                await _folders[index].delete(recursive: true);
                await getDir();
                await Future.delayed(const Duration(milliseconds: 100));
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('No'),
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
    // TODO: implement initState
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

  Future<String?> getSubnet() async {
    for (var interface in await NetworkInterface.list()) {
      if (interface.name == 'wlan0' || interface.name == 'swlan0') {
        for (var addr in interface.addresses) {
          if (addr.address.startsWith('192.168.')) {
            print(addr);
            return addr.address.split('.').sublist(0, 3).join('.');
          }
        }
      }
    }
    return null;
  }

  Future<String> getConnectedDeviceIp() async {
    var subnet = await getSubnet();
    const port = 1234;
    final stream = NetworkAnalyzer.discover2(
      subnet!,
      port,
      timeout: const Duration(seconds: 5),
    );
    String serverIP = '192.168.5.5';
    stream.listen((NetworkAddress addr) {
      if (addr.exists) {
        print('Found device: ${addr.ip}:$port');
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
        title: const Text("Folder Info"),
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
                        Future.delayed(const Duration(milliseconds: 800));
                        Navigator.of(context).pop();
                      }
                      return AlertDialog(
                        title: const Text(
                            'Make sure 2 devices are connected to local wifi network'),
                        content: SizedBox(
                          width:
                              300.0, // set the width as per your requirements
                          height:
                              100.0, // set the height as per your requirements
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: deviceConnected
                                  ? [
                                      const Text("Devices are connected!"),
                                    ]
                                  : [
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 20),
                                      const Text(
                                          "Waiting for connecting devices"),
                                    ],
                            ),
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Close'),
                            onPressed: () {
                              setState(() {
                                syncClosed = true;
                              });
                              if (serverObject != null) serverObject?.close();
                              if (clientObject != null) clientObject?.close();
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              );

              while (!deviceConnected && !syncClosed) {
                await server(1234, 5046);
                // after random time
                final random = math.Random();
                final randomWait = random.nextInt(5) +
                    1; // generate a random number between 1 and 5
                await Future.delayed(Duration(seconds: randomWait));
                if (serverObject != null) serverObject?.close();
                await Future.delayed(const Duration(seconds: 1));
                // get ip
                String serverIp = await getConnectedDeviceIp();
                print(serverIp);
                if (!deviceConnected) {
                  await client("192.168.8.85", 1234, 5046,
                      "/storage/emulated/0/Easync/");
                }
                await Future.delayed(const Duration(seconds: 2));
              }
            },
          ),
        ],
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

  Future<void> saveFilePermanently(PlatformFile file) async {
    // final appStorage = await getApplicationDocumentsDirectory();
    // final Directory? appDocDir = await getExternalStorageDirectory();
    // final newFile = File('${appDocDir?.path}/${file.name}');
    final newFile = File('/storage/emulated/0/Easync/${file.name}');
    File(file.path!).copy(newFile.path);
    getDir();
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
        print('Client connected: ${socket.remoteAddress.address}');
        print('Client connected: ${socket.remoteAddress.address}');
        print('Client connected: ${socket.remoteAddress.address}');
        print('Client connected: ${socket.remoteAddress.address}');
        print('Client connected: ${socket.remoteAddress.address}');
        print('Client connected: ${socket.remoteAddress.address}');
        print('Client connected: ${socket.remoteAddress.address}');
        print('Client connected: ${socket.remoteAddress.address}');
        print('Client connected: ${socket.remoteAddress.address}');
        print('Client connected: ${socket.remoteAddress.address}');
        setState(() {
          deviceConnected = true;
          _dialogKey.currentState?.setState(() {});
        });
        print(deviceConnected);

        // Read messages from the client
        utf8.decoder.bind(socket).listen((String data) async {
          Map<String, dynamic> jsonMap = json.decode(data);
          print(jsonMap);
          // Handle different types of messages
          switch (jsonMap["route"]) {
            case 'SYNC':
              String folderPath = jsonMap["folderPath"];
              Directory folder = Directory(folderPath);
              var filePaths = <String>[];
              await folder.list(recursive: true).forEach((element) {
                if (element is File) {
                  print(element.path);
                  filePaths.add(element.path);
                }
              });
              final jsonData = {
                "route": 'SYNC',
                "folderPath": folderPath,
                "files": filePaths,
              };
              print(filePaths);
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
                  print(response.statusCode);
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
                print(
                    "awaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
                deviceConnected = false;
                syncClosed = true;
              });
              break;
            case 'CLOSE':
              // Close the connection
              server.close();
              print('Client disconnected');
              break;
            default:
              print('Unknown message: $data');
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
        print('Connected to server');
        print('Connected to server');
        print('Connected to server');
        print('Connected to server');
        print('Connected to server');
        print('Connected to server');
        print('Connected to server');
        print('Connected to server');
        print('Connected to server');
        print('Connected to server');
        print('Connected to server');
        print('Connected to server');
        setState(() {
          deviceConnected = true;
          clientObject = socket;
          _dialogKey.currentState?.setState(() {});
        });
        print(deviceConnected);
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
                print(jsonData);
                final jsonString = json.encode(jsonData);
                socket.write(jsonString);
                await Future.delayed(const Duration(seconds: 1));
                var completer = Completer<void>();
                var response =
                    await sendFile(filePath, serverIp, fileServerPort);
                print(response.statusCode);
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
            print(
                "awaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
            setState(() {
              deviceConnected = false;
              syncClosed = true;
            });
            socket.close();
          } else {
            print('Error synchronizing folder');
          }
          // Close the socket and exit the program
          // socket.close();
        });
      });
    } catch (e) {
      print("eeeeeeeeeeeeeee");
      print(e);
    }
  }

  Future<HttpClientResponse> sendFile(
      String filePath, String ipAddress, int port) async {
    print("awaaaaaaaa");
    print(filePath);
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
      print("request $request");
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
            print("awaaaaa 1");
            completer.complete();
          }
        }, onDone: () {
          print("awaaaaa 2");
          consumer.close();
        }, onError: (error) {
          print("awaaaaa 3");
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
