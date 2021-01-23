FROM alpine:3.13

# Use latest github helm version if empty
ARG HELM_VERSION

# Use latest stable kubectl version if empty
ARG KUBECTL_VERSION

ENV KUBECTL_VERSION=$KUBECTL_VERSION
ENV HELM_VERSION=$HELM_VERSION
ENV HELM_HOME=/helm/
ENV YC_HOME=/yc

ENV PATH $HELM_HOME:$YC_HOME/bin:$PATH

RUN apk --no-cache add \
        curl \
        python3 \
        py-crcmod \
        bash \
        libc6-compat \
        openssh-client \
        git \
        gnupg \
        jq

RUN KUBECTL_VERSION=${KUBECTL_VERSION:-`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`} \
 && echo "Usign kubectl version ${KUBECTL_VERSION}" \
 && curl -LO --silent https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
 && chmod +x ./kubectl \
 && mv ./kubectl /usr/local/bin/kubectl

RUN HELM_VERSION=${HELM_VERSION:-`curl --silent "https://api.github.com/repos/helm/helm/releases/latest"  | jq -r .tag_name`} \
 && echo "Usign helm version ${HELM_VERSION}" \
 && curl -O --silent https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz \
 && tar zxf helm-${HELM_VERSION}-linux-amd64.tar.gz \
 && mv linux-amd64 ${HELM_HOME} \
 && rm helm-${HELM_VERSION}-linux-amd64.tar.gz \
 && mkdir -p ${HELM_HOME}/plugins \
 && helm plugin install https://github.com/jkroepke/helm-secrets

RUN curl --silent https://storage.yandexcloud.net/yandexcloud-yc/install.sh \
  | bash -s -- -i ${YC_HOME} -n

VOLUME [ "/root/.config" ]

