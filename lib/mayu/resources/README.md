# Mayu::Resources

This module contains classes for loading resources.

A resource is any type of file that can be used in an app,
usually a component, stylesheet or image.

In development mode, it is possible to watch some directories
for changes and reload resources dynamically as they are updated.

For production, all the resources will be serialized using
[Marshal](https://docs.ruby-lang.org/en/master/Marshal.html),
and static fileswill be generated during build time, and then
loaded in runtime.
