# Copyright DataStax, Inc, 2017
#   Please review the included LICENSE file for more information.
#

FROM dse-base as dse-server-base

ENV DSE_HOME /opt/dse
ENV DSE_AGENT_HOME /opt/agent

# Install missing packages
RUN set -x \
    && mkdir -p ${DSE_HOME} \
    && apt-get update -qq \
    && apt-get install -y python adduser lsb-base procps gzip zlib1g wget debianutils libaio1 sudo \
    && apt-get remove -y python3 \
    && apt-get autoremove --yes \
    && apt-get clean all \
    && rm -rf /var/lib/{apt,dpkg,cache,log}

FROM dse-server-base as base

ARG VERSION=[=version]
ARG TARBALL=dse-${VERSION}-bin.tar.gz
ARG DOWNLOAD_URL=${URL_PREFIX}/${TARBALL}

ARG DSE_AGENT_VERSION=[=agentVersion]
ARG DSE_AGENT_TARBALL=datastax-agent-${DSE_AGENT_VERSION}.tar.gz
ARG DSE_AGENT_DOWNLOAD_URL=${URL_PREFIX}/${DSE_AGENT_TARBALL}

COPY /* /

RUN set -x \
# Download DSE tarball if needed
    && if test ! -e /${TARBALL}; then wget -nv --show-progress --progress=bar:force:noscroll -O /${TARBALL} ${DOWNLOAD_URL} ; fi \
# Unpack tarball
    && tar -C "$DSE_HOME" --strip-components=1 -xzf /${TARBALL} \
    && rm /${TARBALL} \
# Download Agent tarball if needed
    && if test ! -e /${DSE_AGENT_TARBALL}; then wget -nv --show-progress --progress=bar:force:noscroll -O /${DSE_AGENT_TARBALL} ${DSE_AGENT_DOWNLOAD_URL} ; fi \
    && mkdir -p "$DSE_AGENT_HOME" \
    && tar -C "$DSE_AGENT_HOME" --strip-components=1 -xzf /${DSE_AGENT_TARBALL} \
    && rm /${DSE_AGENT_TARBALL}

FROM dse-server-base

MAINTAINER "DataStax, Inc <info@datastax.com>"

COPY files /

COPY --from=base $DSE_HOME $DSE_HOME

COPY --from=base $DSE_AGENT_HOME $DSE_AGENT_HOME

# Create folders
RUN (for dir in /var/lib/cassandra \
                /var/lib/spark \
                /var/lib/dsefs \
                /var/lib/datastax-agent \
                /var/log/cassandra \
                /var/log/spark \
                /config ; do \
        mkdir -p $dir \
        && chgrp -R 0 $dir \
        && chmod 777 $dir ; \
    done )

RUN chgrp -R 0 ${DSE_HOME} \
    && chmod -R g=u ${DSE_HOME} \
    && chgrp -R 0 ${DSE_AGENT_HOME} \
    && chmod -R g=u ${DSE_AGENT_HOME}

ENV PATH $DSE_HOME/bin:$PATH
ENV HOME $DSE_HOME
WORKDIR $HOME

# Expose DSE folders
VOLUME ["/var/lib/cassandra", "/var/lib/spark", "/var/lib/dsefs", "/var/log/cassandra", "/var/log/spark"]

# CASSANDRA PORTS (INTRA-NODE, TLS INTRA-NODE, JMX, CQL, THRIFT, DSEFS INTRA-NODE, INTRA-NODE MESSAGING SERVICE)
EXPOSE 7000 7001 7199 8609 9042 9160

# DSE SEARCH (SOLR)
EXPOSE 8983 8984

# DSE ANALYTICS (SPARK)
EXPOSE 4040 7077 7080 7081 8090 9999 18080

# DSE GRAPH
EXPOSE 8182

# DSEFS
EXPOSE 5598 5599

<#if version.greaterEqualThan('6.7.0')>
EXPOSE 10000

#INSIGHTS
EXPOSE 9103
</#if>

# Run DSE in foreground by default
ENTRYPOINT [ "/entrypoint.sh", "dse", "cassandra", "-f", "-R" ]
