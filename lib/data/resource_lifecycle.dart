abstract interface class DisposableResource {
  void dispose();
}

void disposeResource(Object? resource) {
  if (resource is DisposableResource) {
    resource.dispose();
  }
}
