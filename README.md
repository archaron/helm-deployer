# Helm-deployer
Deploying container for Yandex.Cloud CI/CD integrations.

## Installs:
- ### [kubectl](https://kubernetes.io/docs/reference/kubectl/kubectl/)
  Tool that controls Kubernetes cluster from the deployment container.
  Uses the latest release if not specified in KUBECTL_VERSION
  
- ### Yandex.Cloud CLI utility [yc](https://cloud.yandex.ru/docs/cli/quickstart) 
  For Yandex.Cloud integrations from the deployment container.

- ### [HELM](https://helm.sh/)
  Kubernetes package manager for chart deploying.
  Uses the latest helm release (on github) if not specified in HELM_VERSION
  
- ### [helm-secrets](https://github.com/jkroepke/helm-secrets)
  Helm plugin for [sops](https://github.com/mozilla/sops) secrets decryption when deploying encrypted secrets. 

## Usage example

Some variables must be defined in gitlab CI/CD.
**YC_SA_KEY** - Service Account key for yandex cloud image registry access.
Create new service account in Yandex.Cloud console with roles:
 - container-registry.images.pusher
 - container-registry.images.puller
 - editor

Then copy newly created account identifier. 

```bash
yc iam key create --service-account-id=<service_accont_identifier> --output sa-key.json
```

Store file content to gitlab CI/CD project variables as **file** type variable named YC_SA_KEY 

**YC_CLOUD_ID** - Yandex cloud identifier (cloud-id)

**YC_FOLDER_ID** - Yandex cloud folder identifier (folder-id).

From yandex config list output:  
```bash
yc config list
```

**HELM_GPG_KEY** - GPG key for sops GPG-encrypted secrets decryption.

You may use 
```bash
gpg --generate-key
```
to generate new key (do not use passphrase). Or use some other predefined key.

To get keys list and find your key ID (large hex string):
```bash
gpg -k
```
Export it with:
```bash
gpg --armor --export-secret-keys <gpg_key_id>
```

Later, you can provide this key identifier to sops for secrets encryption:
```bash
sops --pgp <gpg_key_id> secrets.prod.yaml
```


Deploy part of .gitlab-ci.yml file may look like:

```yaml
.deploy_template:
  stage: deploy
  image: archaron/helm-deployer:latest
  script:
    # Setup Yandex Cloud
    - yc config profile create sa-profile
    - yc config set service-account-key ${YC_SA_KEY}
    - yc config set cloud-id ${YC_CLOUD_ID}
    - yc config set folder-id ${YC_FOLDER_ID}
    # Get access credentials for kubectl from yandex cloud provider
    - yc managed-kubernetes cluster get-credentials ${KUBE_CLUSTER} --external
    # Setup GPG for helm secrets
    - echo "$HELM_GPG_KEY" > .helm_secrets_gpg_key.key
    # Deploy chart, stored in .infra folder via helm
    # Values of chart are stored in files named value.<build_variant>.yaml
    # Secret values, encoded with sosp are stored in files named secrets.<build_variant>.yaml
    # ie:
    # for dev environment:
    #  values.dev.yaml
    #  secrets.dev.yaml
    # for prod environment:
    #  values.prod.yaml
    #  secrets.prod.yaml
    
    - cd .infra/
    - helm secrets upgrade --wait --install ${RELEASE_NAME} --namespace ${KUBE_NAMESPACE} --values values.${BUILD_VARIANT}.yaml --values secrets.${BUILD_VARIANT}.yaml --set image.tag=${CI_COMMIT_SHORT_SHA} chart/

# Dev environment deployment
deploy_dev:
  extends: .deploy_template
  variables:
    # Specify kubernetes cluster name to deploy apps to
    KUBE_CLUSTER: "kub-test"  
    # Target namespace
    KUBE_NAMESPACE: "dev"
    BUILD_VARIANT: "dev"
    RELEASE_NAME: "myapp"
  environment:
    name: dev
  when: manual

deploy_prod:
  extends: .deploy_template
  variables:
    KUBE_CLUSTER: "kub-test"
    KUBE_NAMESPACE: "prod"
    BUILD_VARIANT: "prod"
    RELEASE_NAME: "myapp"
  environment:
    name: prod
  only:
    - master
  when: manual


```

Based on the [Vasiliy Ozerov](https://github.com/vozerov) ideas.