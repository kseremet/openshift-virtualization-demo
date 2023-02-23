# Red Hat Advanced Cluster Management, OpenShift GitOps and OpenShift Virtualization demo

This repository contains instructions and files for a demonstration
deployment that combines Red Hat Advanced Cluster Management with OpenShift
GitOps and OpenShift Virtualization. This demo shows how a CI/CD workflow of
[`VirtualMachines`](https://kubevirt.io/user-guide/) across multiple clusters
could look like.

## Requirements

- One OpenShift cluster acting as hub cluster
    - Needs to be publicly accessible
- One or more OpenShift clusters acting as managed clusters
    - Can be in private networks
    - Virtualization has to be available
    - Nested virtualization is fine for demonstration purposes

## Setting up the demo

Follow these steps to set up a working demonstration environment.

### What is a hub cluster?

The hub cluster is the cluster on which ACM and GitOps are running on. It
acts as an inventory and carries out all management actions. It is not
running any actual workloads, these run on managed clusters. For more
information see [here](https://open-cluster-management.io/concepts/architecture/#overview).

### Installing ACM on the hub cluster

1. Login as cluster administrator on the UI of the hub cluster
2. Open the `Administrator` view if it is not already selected
2. In the menu click on `Operators` and open `OperatorHub`
3. In the search type `Advanced Cluster Management for Kubernetes` and click
   on it in the results
4. Click on `Install`, keep defaults and click on `Install` again
5. Wait until `MultiClusterHub` can be created and create it
6. Wait until the created `MultiClusterHub` is ready (`Operators` -->
   `Installed Operators` --> see status of ACM)

### Adding managed clusters to ACM on the hub cluster

Managed clusters can be added to ACM in two ways:

1. Add existing cluster to ACM
2. Create new cluster with ACM

> Note: For the sake of simplicity we will let ACM create the managed
> clusters in this demo on a public cloud provider. Please note that nested
> virtualization is not supported in production deployments.

To create one or more managed clusters follow these steps:

1. Login as cluster administrator on the UI of the hub cluster
2. At the top of the menu select `All Clusters` (`local-cluster` should be
   selected initially)
3. Add credentials for you cloud provider by clicking on `Credentials` in
   the menu and then clicking on `Add credentials`
4. Click on `Infrastructure` and then on `Clusters` in the menu
5. Click `Create cluster`, select your cloud provider and complete the
   wizard (use the default cluster set for now)

> Note: When using Azure as cloud provider select instance type
`Standard_D8s_v3` for the control plane and `Standard_D4s_v3` for the worker
> nodes.

### Creating a ManagedClusterSet to group managed clusters

Managed clusters can be grouped in `ManagedClusterSets`.

To add managed clusters to a new set follow these steps:

1. Login as cluster administrator on the UI of the hub cluster
2. At the top of the menu select `All Clusters` (`local-cluster` should be
   selected initially)
4. Click on `Infrastructure` and then on `Clusters` in the menu
3. Click on `Cluster sets` and then on `Create cluster set`
4. Enter `managed` as name for the new set and click on `Create`
5. Click on `Managed resource assignments`
6. Select all clusters you want to add, click on `Review` and then on `Save`

Now we have a `ManagedClusterSet` that can be used to make the managed clusters
available to GitOps.

### Installing OpenShift GitOps on the hub cluster

1. Login as cluster administrator on the UI of the hub cluster
2. Open the `Administrator` view if it is not already selected
2. In the menu click on `Operators` and open `OperatorHub`
3. In the search type `Red Hat OpenShift GitOps` and click
   on it in the results
4. Click on `Install`, keep defaults and click on `Install` again
6. Wait until OpenShift GitOps is ready (`Operators` -->
   `Installed Operators` --> see status of OpenShift GitOps)

> Note: Because OpenShift GitOps is based on the ArgoCD project the terms
> `OpenShift GitOps` and `ArgoCD` in the following sections are
> interchangeable.

### Log in to the OpenShift GitOps UI

1. Login as cluster administrator on the UI of the hub cluster
2. Open the `Administrator` view if it is not already selected
3. In the menu click on `Networking` and open `Routes`
4. In the `Projects` dropdown select `openshift-gitops`
5. There will be a `Route` called `openshift-gitops-server`, the location of
   this `Route` is the URL to the GitOps UI
6. You can log in to the GitOps UI with your OpenShift credentials

### Making a set of managed clusters available to OpenShift GitOps

To make a set of managed clusters available to OpenShift GitOps a tight
integration between ACM and GitOps was added.

Follow these steps to make the managed clusters available to GitOps:

1. Copy the login command for the commandline by clicking on your username on
   the top right and then click on `Copy login command`
2. Run the copied command in your commandline
3. Create a `ManagedClusterSetBinding` in the `openshift-gitops` namespace
   to make the `ManagedClusterSet` available in this namespace
   - See file [managedclustersetbinding.yaml](./acm-gitops-integration/managedclustersetbinding.yaml)
   - Run `oc create -f acm-gitops-integration/managedclustersetbinding.yaml`
4. Create a `Placement` to let ACM decide which clusters should be made
   available to GitOps
    - See file [placement.yaml](./acm-gitops-integration/placement.yaml)
    - Run `oc create -f acm-gitops-integration/placement.yaml`
    - For the sake of simplicity this will select the whole
      `ManagedClusterSet`, but advanced use cases are possible
5. Create a `GitOpsCluster` to finally make the selected clusters available to
   GitOps
   - See file [gitopscluster.yaml](./acm-gitops-integration/gitopscluster.yaml)
   - Run `oc create -f acm-gitops-integration/gitopscluster.yaml`

### Short introduction to ApplicationSet

The ArgoCD `ApplicationSet` is a CRD building on ArgoCD `Applications`
targeted to deploy and manage `Applications` across multiple clusters while
using the same manifest or declaration. It is possible to deploy multiple
`ApplicationSets` which are contained in one monorepo. By using generators
it is possible to dynamically select a subset of clusters available to
ArgoCD to deploy resources on to.

In this demo we are going to use `ApplicationSets` to deploy OpenShift
Virtualization and `VirtualMachines` to multiple clusters while using
the same declaration of resources for all clusters.

For more information on `ApplicationSets` see the [documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset).

### Deploying OpenShift Virtualization to one or more managed clusters

To deploy OpenShift Virtualization to all managed clusters with the help of
an `ApplicationSet` run the following command:

```shell
oc create -f applicationsets/virtualization/applicationset-virtualization.yaml
```

This will create an `Application` for each managed cluster that deploys
OpenShift Virtualization with its default settings. The `Application` will
ensure that the namespace `openshift-cnv` exists and it will automatically
apply any changes to this repository or undo changes which are not in this
repository. Sync waves are used to ensure that resources are created in the
right order.

Order of resource creation:

1. `OperatorGroup`
2. `Subscription`
3. `HyperConverged`

Because the `HyperConverged` CRD is unknown to ArgoCD the sync option
`SkipDryRunOnMissingResource=true` is set to allow ArgoCD to create a CR
without knowing its CRD.

To see what is actually deployed have a look into the following directory:
`applicationsets/virtualization/manifests`.

#### Forcing a specific version of OpenShift Virtualization

There is only one update channel for OpenShift Virtualization (called
`stable`) so the appropriate version for the managed cluster is selected
automatically.

To force a specific version from the channel do the following:

1. Make sure that [`grpcurl`](https://github.com/fullstorydev/grpcurl) and
[`jq`](https://stedolan.github.io/jq/) are available on your machine
2. Extract the available [`CSV`](https://olm.operatorframework.io/docs/concepts/crds/clusterserviceversion/) versions from the Operator registry
   1. Login to the commandline of the managed cluster
   2. Run `oc port-forward service/redhat-operators -n openshift-marketplace 50051:50051`
   3. In a separate terminal run `grpcurl -plaintext localhost:50051 api.Registry/ListBundles | jq 'select(.csvName | match ("kubevirt-hyperconverged-operator")) | .version'`
3. Set the following fields in the `Operator` spec
   - `installPlanApproval`: `Manual`
   - `startingCSV`: Your desired and available CSV version

This technique can for example be used to control the upgrade
process of OpenShift Virtualization in a declarative way.

### Deploying a `VirtualMachine` to one or more managed clusters

To deploy a Fedora `VirtualMachine` on all managed clusters with the help of
an `ApplicationSet` run the following command:

```shell
oc create -f applicationsets/demo-vm/applicationset-demo-vm.yaml
```

This will create an `Application` for each managed cluster that deploys
a simple `VirtualMachine` on each cluster. It uses the Fedora `DataSource`
available by default on the cluster to boot a Fedora cloud image.

To see what is actually deployed have a look into the following directory:
`applicationsets/demo-vm/manifests`.

### How to start or stop a `VirtualMachine`

To start of stop a `VirtualMachine` you need to edit the `spec.running`
field of a `VirtualMachine` and set it to the corresponding value (`false`
or `true`). If the `VirtualMachine` has an appropriate termination grace
period (`spec.template.spec.terminationGracePeriodSeconds`) setting this
value to `false` will gracefully shut down the `VirtualMachine`. When
setting the timeout grace period to 0 seconds the `VirtualMachine` is
stopped immediately however.

To deploy new changes with ArgoCD you need to commit changes to the Git
repository of an `Application`. The `ApplicationSets` in this repository
use the URL of this repository as `repoURL`, so to be able to make changes you
need to fork this repository and adjust the `repoURL` in the provided
`ApplicationSets`. Don't forget to update any existing `ApplicationSets` on
your hub cluster.

To start or stop a `VirtualMachine` update the manifest and commit and push
it to your repository. In the ArgoCD UI select the `Application` of the
`VirtualMachine` and click `Refresh` to apply the change immediately.
Otherwise, it will take some time until ArgoCD scans the repository and
picks up the change.

### Advanced usage of ACM Placements with OpenShift GitOps

For the sake of simplicity the `Placement` created in this demo selects the
whole `ManagedClusterSet`, but more advanced use cases are possible.

ACM can dynamically select a sub set of clusters from the
`ManagedClusterSet` while following a defined set of criteria. This for
example allows to schedule `VirtualMachines` on clusters with the most
resources available at the time of the placement decision.

For more on this topic see
[Using the Open Cluster Management Placement for Multicluster Scheduling](https://cloud.redhat.com/blog/using-the-open-cluster-management-placement-for-multicluster-scheduling).

### Alternative way of deploying OpenShift Virtualization to managed clusters

An [ACM add-on](https://open-cluster-management.io/developer-guides/addon/)
that deploys OpenShift Virtualization to managed clusters was implemented
for evaluation purposes. The add-on is fully functional and can deploy
OpenShift Virtualization to all managed clusters that have a specific label set.

Allthough the add-on the serves the purpose of deploying OpenShift
Virtualization it was found to be unnecessary complex when OpenShift GitOps
is available too, because it is only deploying a small set of static
manifests which can be deployed by GitOps too. In contrast to its use stands
the additional maintenance burden and resource usage of another container
running on the cluster. Therefore, it was decided to not follow this path
further.

### Integration with Ansible

ACM can be integrated with Ansible to trigger Playbook runs after certain
events. To make use of `VirtualMachines` in Ansible a dynamic inventory is
needed, which makes the `VirtualMachines` available and accessible to Ansible.

There is already a collection of [KubeVirt modules](https://github.com/kubevirt/kubevirt-ansible/)
for Ansible, this collection however is deprecated and no longer working.

For evaluation purposes [a fork](https://github.com/0xFelix/kubernetes.kubevirt)
was created. This fork provides limited functionaly but shows
that this type of integration is still possible. A demo of this Ansible
collection can be found [here](https://github.com/0xFelix/kubevirt-inventory-demo).

### Future use cases

A future use case is to pre-configure a `VirtualMachine` on a cluster
and then export it into a blob format which can be stored somewhere where it
can be accessed from other clusters. The blob could then be imported into
other clusters to allow deployment of replicas of a pre-configured
`VirtualMachine` across multiple clusters.

A possible blob format for this kind of export/import feature could be
[ContainerDisks](https://kubevirt.io/user-guide/virtual_machines/disks_and_volumes/#containerdisk)
which are already supported by OpenShift Virtualization.

To show this is already possible with the current `ContainerDisk`
implementation a Proof-Of-Concept was created. The PoC can be found [here](https://github.com/0xFelix/kubevirt/tree/virtctl-exportcd).
