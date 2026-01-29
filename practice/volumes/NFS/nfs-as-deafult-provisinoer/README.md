You need root privileges and the NFS server setup is just the first step for Kubernetes persistent storage. Here's a complete, detailed guide using the NFS server IP (192.168.1.100) and share (/mnt/nfs-share) from your prerequisites.

## 1. NFS Server Setup (Ubuntu)
Run these on your dedicated NFS server machine (10.0.1.10):#Nfs Server PrivateIP

```
sudo apt update
sudo apt install nfs-kernel-server
sudo mkdir -p /mnt/nfs-share
sudo chown nobody:nogroup /mnt/nfs-share
sudo chmod 777 /mnt/nfs-share
```

Edit `/etc/exports`:
```
sudo nano /etc/exports
```
Add this line (replace `*` with specific Kubernetes node IPs for security):
```
/mnt/nfs-share *(rw,sync,no_subtree_check,no_root_squash)
```

Apply and restart:
```
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server
sudo showmount -e localhost  # Verify export
```

**Firewall**: Open NFS ports (TCP/UDP 2049, 111):
```
sudo ufw allow from 10.0.1.10/24 to any port nfs  # Adjust subnet
sudo ufw reload
```

## 2. NFS Client on All Kubernetes Nodes
On **every** Kubernetes node (control plane + workers):
```
sudo apt update
sudo apt install nfs-common
```

Test connectivity from each node:
```
showmount -e 10.0.1.10
sudo mkdir /mnt/test && sudo mount -t nfs 10.0.1.10:/mnt/nfs-share /mnt/test
ls /mnt/test  # Should work
sudo umount /mnt/test
```

## 3. Kubernetes NFS Provisioner
Create namespace and install nfs-subdir-external-provisioner (dynamic PVs):

```
kubectl create namespace nfs-provisioner
```

**Option A: Helm (recommended)**:
```
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace nfs-provisioner \
  --set nfs.server=10.0.1.10 \
  --set nfs.path=/mnt/nfs-share \
  --set storageClass.name=nfs-storage \
  --set storageClass.onDelete=true
```

**Option B: YAML manifests** (create `nfs-provisioner.yaml`):
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nfs-provisioner
---
apiVersion: v1
kind: StorageClass
metadata:
  name: nfs-storage
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  onDelete: "delete"  # or "retain"
---
# Deployment and RBAC (full manifest from kubernetes-sigs/nfs-subdir-external-provisioner repo)
```
Then: `kubectl apply -f nfs-provisioner.yaml`

Verify:
```
kubectl get storageclass nfs-storage
kubectl get pods -n nfs-provisioner  # Should be Running
```

## 4. Test with PVC and Pod
Create `test-pvc.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
spec:
  storageClassName: nfs-storage
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
```

Apply and test:
```
kubectl apply -f test-pvc.yaml
kubectl get pvc test-nfs-pvc  # Should be Bound

# Pod to test
kubectl run nfs-test --image=busybox -it --rm --restart=Never -- sh
# Inside pod: touch /mnt/test-file && ls /mnt/
```

## 5. Troubleshooting
| Issue | Check |
|-------|-------|
| PVC Pending | `kubectl describe pvc` + provisioner logs: `kubectl logs -n nfs-provisioner deploy/nfs-provisioner`  [blog.francium](https://blog.francium.tech/setting-up-nfs-storage-for-kubernetes-a-complete-guide-47220cdb7ba7?gi=e306c1e8f17a) |
| Mount fails | Node NFS client installed? Firewall? `kubectl describe pod`  [lucyllewy](https://lucyllewy.com/tutorials/kubernetes-k3s/nfs/) |
| Permission denied | `/etc/exports` has `no_root_squash`? Permissions 777?  [blog.francium](https://blog.francium.tech/setting-up-nfs-storage-for-kubernetes-a-complete-guide-47220cdb7ba7?gi=e306c1e8f17a) |
| Network unreachable | `ping 192.168.1.100` + `telnet 192.168.1.100 2049` from nodes  [knowledgebase.code-de](https://knowledgebase.code-de.org/en/latest/kubernetes/Create-and-access-NFS-server-from-Kubernetes-on-CODE-DE.html) |

Your NFS share now provides dynamic ReadWriteMany storage for stateful apps! [blog.francium](https://blog.francium.tech/setting-up-nfs-storage-for-kubernetes-a-complete-guide-47220cdb7ba7?gi=e306c1e8f17a)


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Your NFS provisioner is working perfectly—PVC is Bound and the pod test succeeded! The issue is NFS client access from Kubernetes nodes.

## Fix NFS Mount Failures on Nodes

**Problem**: Node 10.0.1.139 gets "access denied by server" because `/etc/exports` only allows specific IPs (10.0.1.140,139,10), but Kubernetes pods may run from different node IPs or need broader access.

**On NFS server (10.0.1.10)**, update `/etc/exports` for all cluster nodes:

```
sudo nano /etc/exports
```

**Option 1: Allow entire 10.0.1.0/24 subnet** (safer):
```
/mnt/nfs-share 10.0.1.0/24(rw,sync,no_subtree_check,no_root_squash)
```

**Option 2: List ALL Kubernetes node IPs explicitly**:
```
/mnt/nfs-share 10.0.1.10,10.0.1.139,10.0.1.140,10.0.1.120(rw,sync,no_subtree_check,no_root_squash)
```

Apply changes:
```
sudo exportfs -ra
sudo showmount -e localhost  # Verify new exports
sudo systemctl restart nfs-kernel-server
```

## Verify Node Access
Test from **each** Kubernetes node:

```bash
# On 10.0.1.139 (failing node)
sudo apt install nfs-common  # If missing
showmount -e 10.0.1.10
sudo mount -t nfs 10.0.1.10:/mnt/nfs-share /mnt/test
ls /mnt/test && sudo umount /mnt/test
```

## Test Kubernetes Pod with PVC
Create proper test pod `nfs-test-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nfs-test-pod
spec:
  containers:
  - name: test
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo $(date) >> /mnt/test-file; ls -l /mnt/; sleep 5; done"]
    volumeMounts:
    - name: nfs-volume
      mountPath: /mnt
  volumes:
  - name: nfs-volume
    persistentVolumeClaim:
      claimName: test-nfs-pvc
```

```bash
kubectl apply -f nfs-test-pod.yaml
kubectl get pod nfs-test-pod  # Should be Running
kubectl logs nfs-test-pod -f  # Watch file writes
kubectl exec nfs-test-pod -- ls -l /mnt/  # Verify files
```

## Status Check
| Component | Status | Notes |
|-----------|--------|-------|
| NFS Server | ✅ | Exports visible, service running |
| Provisioner | ✅ | Pod Running, StorageClass ready |
| PVC | ✅ | Bound to dynamic PV |
| Node Mounts | ❌➡️✅ | Fix /etc/exports then test |
| Pod Access | ✅ | Busybox test worked |

Your setup is 95% complete—after exports fix, you'll have fully functional NFS storage for Kubernetes!

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#optinal

**MongoDB + Spring Boot with NFS as DEFAULT Storage Provisioner (Dynamic PV)**

## 1. Install NFS CSI Driver + StorageClass
```bash
# Add NFS CSI Helm repo
helm repo add nfs-csi-driver https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm repo update

# Install NFS CSI Driver
helm install csi-driver-nfs nfs-csi-driver/csi-driver-nfs --namespace kube-system

# Create NFS StorageClass (Dynamic Provisioning)
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"  # DEFAULT!
provisioner: nfs.csi.k8s.io
parameters:
  server: 192.168.1.100          # YOUR NFS SERVER IP
  share: /mnt/nfs-share          # YOUR NFS EXPORT PATH
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

# Disable old default StorageClass (local-path)
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

## 2. Simplified App YAML (`nfs-dynamic-app.yml`) - NO Manual PV!
```yaml
---
# MongoDB ReplicaSet (Dynamic NFS PVC)
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: mongodbrs
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
      - name: mongo
        image: mongo:7.0
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: devdb
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: devdb123
        - name: MONGO_INITDB_DATABASE
          value: myappdb
        volumeMounts:
        - name: mongo-storage
          mountPath: /data/db
      volumes:
      - name: mongo-storage
        persistentVolumeClaim:
          claimName: mongo-nfs-pvc  # Dynamic!

---
# Dynamic PVC (Uses DEFAULT nfs-csi StorageClass)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-nfs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  # No storageClassName = Uses DEFAULT nfs-csi!

---
# MongoDB Service
apiVersion: v1
kind: Service
metadata:
  name: mongosvc
spec:
  type: ClusterIP
  selector:
    app: mongo
  ports:
  - port: 27017
    targetPort: 27017

---
# Spring Boot Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springappdeployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: springapp
  template:
    metadata:
      labels:
        app: springapp
    spec:
      containers:
      - name: springapp
        image: dockeruma03/spring-boot-mongo:1
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_DATA_MONGODB_HOST
          value: mongosvc
        - name: SPRING_DATA_MONGODB_PORT
          value: "27017"
        - name: SPRING_DATA_MONGODB_USERNAME
          value: devdb
        - name: SPRING_DATA_MONGODB_PASSWORD
          value: devdb123
        - name: SPRING_DATA_MONGODB_DATABASE
          value: myappdb
        - name: SPRING_DATA_MONGODB_AUTHENTICATION_DATABASE
          value: admin

---
# Spring Boot Service
apiVersion: v1
kind: Service
metadata:
  name: springappsvc
spec:
  type: NodePort
  selector:
    app: springapp
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 32577
```

## Deploy
```bash
# UPDATE NFS SERVER IP & SHARE PATH above!
kubectl delete all,pvc --all -l app=springapp,app=mongo
kubectl apply -f nfs-dynamic-app.yml

# Verify dynamic provisioning
kubectl get storageclass
kubectl get pvc,pv
```

## Expected Output
```
STORAGECLASS   PROVISIONER      RECLAIMPOLICY   VOLUMEBINDINGMODE   DEFAULT
nfs-csi        nfs.csi.k8s.io   Delete          Immediate          ✅ (default)

PVC            STATUS   CAPACITY   STORAGECLASS
mongo-nfs-pvc  Bound    10Gi       nfs-csi
```

## **Key Benefits of NFS Default Provisioner**
✅ **Dynamic PV creation** - No manual PV needed  
✅ **Default StorageClass** - `kubectl apply` auto-provisions  
✅ **Multi-node access** - Works across cluster  
✅ **Scalable** - Unlimited PVCs from single NFS share  
✅ **Simple YAML** - No storage configuration per-app  

**Replace `192.168.1.100:/mnt/nfs-share` with your NFS server details!** 🎉



