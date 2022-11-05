# Resources::Types

These classes implement behaviors for different types of resources.

Some resources can generate static files during build time.
These static files should have a predictable filename based
on the content hash + some options.
Compressable types should be brotlied.
The generated files could be named like this:

    47DEQpj8HBSa-_TImW-5JCeuQeRkm5NMpJWZG3hSuFU=.css
    47DEQpj8HBSa-_TImW-5JCeuQeRkm5NMpJWZG3hSuFU=.css.br
    M4CmsIPAxdPZRaERcnCA8mL7whpfFfArIziflCS0iUY=.png
    M4CmsIPAxdPZRaERcnCA8mL7whpfFfArIziflCS0iUY=640w.png
    M4CmsIPAxdPZRaERcnCA8mL7whpfFfArIziflCS0iUY=768w.png
    M4CmsIPAxdPZRaERcnCA8mL7whpfFfArIziflCS0iUY=960w.png
    M4CmsIPAxdPZRaERcnCA8mL7whpfFfArIziflCS0iUY=1024w.png
    M4CmsIPAxdPZRaERcnCA8mL7whpfFfArIziflCS0iUY=1366w.png
    M4CmsIPAxdPZRaERcnCA8mL7whpfFfArIziflCS0iUY=1600w.png
    M4CmsIPAxdPZRaERcnCA8mL7whpfFfArIziflCS0iUY=1920w.png
    eN3Sv_BzhBLUw72oUgA5sCa8YF74CJm0Z8Z97eQgofk=.css
    eN3Sv_BzhBLUw72oUgA5sCa8YF74CJm0Z8Z97eQgofk=.css.br

## Resources::Types::Component

Loads a `.rb`-file or `.haml`-file and transpiles the latter,
then evaluates the code in the scope of a new class that inherits
`Mayu::Component::Base`.

## Resources::Types::Image

Loads an image, stores its size and information about which
versions to generate for `srcset`.

During build time it will generate smaller versions of the image,
and store them in the configured directory for static files.
