/// Kleine gemeinsame Schnittstelle fuer Services, die Ressourcen freigeben
/// muessen, aber nicht zwingend Flutters `ChangeNotifier` oder `Stream` sind.
abstract interface class DisposableResource {
  void dispose();
}

/// Ruft `dispose` nur dann auf, wenn das Objekt diese Projekt-Schnittstelle
/// implementiert.
void disposeResource(Object? resource) {
  if (resource is DisposableResource) {
    resource.dispose();
  }
}
