# The /publisher directory

The `/publisher` directory is copied in full into the docker image as
defined by the [`../Dockerfile`](../Dockerfile) file.

For each "ontology family" (such as FIBO) the publisher can generate
multiple "products". In that sense we see the series of "products" as
a "product line" or "product family".

Each product has its own scripts and other collateral to do its thing.
Have a look at the [readme](./product/README.md) in the `/publisher/product`
directory.

## See Also

- [../README.md](../README.md)
- [./product/README.md](./product/README.md)