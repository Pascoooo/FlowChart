import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';

import 'file_model.dart';

part 'file_system_event.dart';
part 'file_system_state.dart';

class FileSystemBloc extends Bloc<FileSystemEvent, FileSystemState> {
  final Uuid _uuid = const Uuid();

  FileSystemBloc() : super(const FileSystemInitial()) {
    on<CreateNewEntry>(_onCreateNewEntry);
    on<OpenFile>(_onOpenFile);
    on<CreateNewRoot>(_onCreateNewRoot);
  }

  // La cartella radice viene gestita dal BLoC
  late Directory _root;

  /// Inizializza il filesystem con una cartella radice.
  Future<void> _onCreateNewRoot(
      CreateNewRoot event,
      Emitter<FileSystemState> emit,
      ) async {
    _root = Directory(
      id: 'root',
      name: 'Progetti',
      parentId: '',
      children: [],
    );
    emit(FileSystemLoaded(root: _root, activeFileId: null));
  }

  /// Gestisce la creazione di un nuovo file o directory.
  Future<void> _onCreateNewEntry(
      CreateNewEntry event,
      Emitter<FileSystemState> emit,
      ) async {
    if (state is! FileSystemLoaded) {
      emit(const FileSystemError(message: 'Filesystem non caricato.'));
      return;
    }

    final loadedState = state as FileSystemLoaded;

    // Trova il genitore corretto usando un metodo di ricerca.
    final Directory? parent = _findDirectoryById(loadedState.root, event.parentId);

    if (parent == null) {
      emit(loadedState.copyWith(
        error: 'Impossibile trovare la cartella di destinazione.',
      ));
      return;
    }

    // Controlla se il nome esiste già
    bool nameExists = parent.children.any((entry) => entry.name == event.name);
    if (nameExists) {
      emit(loadedState.copyWith(
        error: 'Esiste già un file o cartella con questo nome.',
      ));
      return;
    }

    // Crea la nuova entry
    FileSystemEntry newEntry;
    if (event.isDir) {
      newEntry = Directory(
        id: _uuid.v4(),
        name: event.name,
        parentId: event.parentId,
        children: [],
      );
    } else {
      newEntry = File(
        id: _uuid.v4(),
        name: event.name,
        parentId: event.parentId,
      );
    }

    // Aggiungi la nuova entry ai figli del genitore
    parent.children.add(newEntry);

    // Emette un nuovo stato con la lista di figli aggiornata.
    // Viene creata una nuova copia dello stato per garantire l'immutabilità.
    emit(FileSystemLoaded(root: loadedState.root, activeFileId: loadedState.activeFileId));
  }

  /// Gestisce l'apertura di un file.
  Future<void> _onOpenFile(OpenFile event, Emitter<FileSystemState> emit) async {
    if (state is FileSystemLoaded) {
      final loadedState = state as FileSystemLoaded;
      emit(loadedState.copyWith(activeFileId: event.file.id));
    }
  }

  /// Metodo ricorsivo per trovare una directory per ID.
  Directory? _findDirectoryById(Directory currentDir, String id) {
    if (currentDir.id == id) {
      return currentDir;
    }

    for (final child in currentDir.children) {
      if (child is Directory) {
        final foundDir = _findDirectoryById(child, id);
        if (foundDir != null) {
          return foundDir;
        }
      }
    }
    return null;
  }
}
