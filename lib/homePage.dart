import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'detailfolder.dart';
import 'package:file_picker/file_picker.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<String> createFolderInAppDocDir(String folderName) async {
    //Get this App Document Directory
    final Directory? _appDocDir = await getExternalStorageDirectory();
    //App Document Directory + folder name
    final Directory _appDocDirFolder =
    Directory('${_appDocDir?.path}/$folderName/');
    if (await _appDocDirFolder.exists()) {
      //if folder already exists return path
      return _appDocDirFolder.path;
    } else {
      //if folder not exists create folder and then return its path
      final Directory _appDocDirNewFolder =
      await _appDocDirFolder.create(recursive: true);
      return _appDocDirNewFolder.path;
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
    final directory = await getExternalStorageDirectory();
    final dir = directory?.path;
    String pdfDirectory = '$dir/';
    final myDir = Directory(pdfDirectory);
    print(myDir);
    setState(() {
      _folders = myDir.listSync(recursive: false, followLinks: false);
    });
  }

  Future<void> _showDeleteDialog(int index) async {
    return showDialog<void>(
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
                await _folders[index].delete(recursive : true);
                getDir();
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
            },
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded),
            onPressed: () {
              _showMyDialog();
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
                                return const Icon(
                                  Icons.file_copy_outlined,
                                  size: 100,
                                  color: Colors.orange,
                                );
                              } else {
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(context,
                                        MaterialPageRoute(builder: (builder) {
                                          return InnerFolder(
                                              filespath: _folders[index].path);
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

  Future getFileType(file) {
    return file.stat();
  }
}