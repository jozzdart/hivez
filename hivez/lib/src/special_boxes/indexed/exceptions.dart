part of 'indexed.dart';

class IndexedBoxException extends HivezBoxException {
  IndexedBoxException({
    required super.boxName,
    required super.message,
    super.cause,
    super.stackTrace,
  });
}

class IndexRebuildFailed extends IndexedBoxException {
  IndexRebuildFailed({required super.boxName, super.cause, super.stackTrace})
      : super(message: "Index rebuild failed");
}

class IndexCorruptionDetected extends IndexedBoxException {
  IndexCorruptionDetected(
      {required super.boxName, super.cause, super.stackTrace})
      : super(message: "Index is corrupt, requires rebuild.");
}
