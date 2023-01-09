###
### stage1: clone source and build redbean
###

FROM alpine as stage1

ARG CLUON_BUILDDIR=/cluon/build
ARG CLUON_TARGETDIR=/cluon/target
ARG CLUON_COSMODIR=$CLUON_BUILDDIR/cosmo
ARG COSMO_CLONE_URL=https://github.com/jart/cosmopolitan
ARG COSMO_TAG=master
ARG COSMO_PULL=
ARG REDBEAN_COM_FILE=redbean.com
ARG COSMO_MAKE_TARGET=o//tool/net/$REDBEAN_COM_FILE
ARG COSMO_MAKE_MODE=

RUN apk add git make

RUN mkdir -p $CLUON_BUILDDIR $CLUON_TARGETDIR

# The `grep` line below is a canary test to see if we're working with a cached
# repo - if we're not then we need to clone
RUN --mount=type=cache,target=$CLUON_BUILDDIR,sharing=locked \
    grep -q Honeybadger $CLOUN_COSMODIR/README.md 2>/dev/null || \
    git clone $COSMO_CLONE_URL $CLUON_COSMODIR

# If COSMO_TAG is set then run `git checkout` for it
RUN --mount=type=cache,target=$CLUON_BUILDDIR,sharing=locked \
    [ -z "$COSMO_TAG" ] || { \
        cd $CLUON_COSMODIR && \
        git checkout $COSMO_TAG; \
    }

# If COSMO_PULL is set then run `git pull` on the repo dir
RUN --mount=type=cache,target=$CLUON_BUILDDIR,sharing=locked \
    [ -z "$COSMO_PULL" ] || { \
        cd $CLUON_COSMODIR && \
        git pull; \
    }

# Build!
RUN --mount=type=cache,target=$CLUON_BUILDDIR,sharing=locked \
    cd $CLUON_COSMODIR && \
	make clean && \
    make -j$(nproc) MODE=$COSMO_MAKE_MODE $COSMO_MAKE_TARGET && \
    cp -v $COSMO_MAKE_TARGET $CLUON_TARGETDIR

###
### stage2: assimilate the binary and customize the redbean amagalmation
###

FROM alpine as stage2

ARG CLUON_BUILDDIR=/cluon/build
ARG CLUON_TARGETDIR=/cluon/target
ARG CLUON_BEANFILES_DIR=$CLUON_BUILDDIR/beanfiles
ARG REDBEAN_COM_FILE=redbean.com
ARG REDBEAN_COM_PATH=$CLUON_BUILDDIR/$REDBEAN_COM_FILE

RUN apk add zip

RUN mkdir -p $CLUON_BUILDDIR $CLUON_TARGETDIR $CLUON_BEANFILES_DIR

# Get the redbean.com binary from the first stage
COPY --from=stage1 $CLUON_TARGETDIR/$REDBEAN_COM_FILE $REDBEAN_COM_PATH

# Assimilate the binary to ELF
RUN $REDBEAN_COM_PATH --assimilate

# Copy in the beanfiles dir from the host
COPY beanfiles $CLUON_BEANFILES_DIR

RUN find $CLUON_BUILDDIR >&2

# Add the files from the 'add' dir to the amagalmation
WORKDIR $CLUON_BEANFILES_DIR/add
RUN find . -type f -exec zip $REDBEAN_COM_PATH {} + >&2

# Remove the file _names_ that are in the 'del' dir from the amagalmation
WORKDIR $CLUON_BEANFILES_DIR/del
RUN find . -type f -exec zip -d $REDBEAN_COM_PATH {} + >&2

RUN cp -v $REDBEAN_COM_PATH $CLUON_TARGETDIR

###
### stage3: clean slate for final execution environment
###

FROM alpine as stage3

ARG CLUON_DIR=/cluon
ARG CLUON_TARGETDIR=$CLUON_DIR/target
ARG REDBEAN_COM_FILE=redbean.com
ARG REDBEAN_FINALPATH=$CLUON_DIR/redbean

COPY --from=stage2 $CLUON_TARGETDIR/$REDBEAN_COM_FILE $REDBEAN_FINALPATH

ENV REDBEAN=$REDBEAN_FINALPATH

ENTRYPOINT ["sh", "-x", "-c", "$REDBEAN"]
