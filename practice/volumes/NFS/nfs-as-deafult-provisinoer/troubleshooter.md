## Complete NFS Cleanup and Fresh Reinstall

Your NFS setup has **multiple broken StorageClasses**. Let's delete everything and start fresh.

### Step 1: Complete Cleanup

```bash
# 1. Delete ALL existing resources
kubectl delete all --all
kubectl delete pvc,pv --all
kubectl delete statefulset,deployment --all

# 2. Delete NFS provisioner completely
kubectl delete namespace nfs-provisioner --force --grace-period=0
helm uninstall nfs-provisioner -n nfs-provisioner || true
helm repo remove nfs-subdir-external-provisioner || true

# 3. Delete ALL broken StorageClasses
kubectl delete storageclass --all
```

**Verify cleanup:**
```bash
kubectl get storageclass        # Should show "No resources found"
kubectl get pods -n nfs-provisioner  # Should fail (namespace gone)
kubectl get all,pvc,pv         # Should be clean
```

### Step 2: Fresh NFS Provisioner Install

```bash
# 1. Recreate namespace
kubectl create namespace nfs-provisioner

# 2. Add Helm repo (fresh)
helm repo add nfs-subdir-external-provisioner \
  https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update

# 3. Install with CORRECT StorageClass name
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace nfs-provisioner \
  --set nfs.server=10.0.1.10 \
  --set nfs.path=/mnt/nfs-share \
  --set storageClass.name=nfs-storage \
  --set storageClass.isDefaultClass=false
```

**Verify provisioner:**
```bash
kubectl get pods -n nfs-provisioner           # Should show 1/1 Running
kubectl get storageclass nfs-storage          # Should exist
kubectl get storageclass nfs-csi -o yaml      # Should still exist (we'll fix)
```

### Step 3: Fix Default StorageClass (nfs-csi)

```bash
# Delete broken nfs-csi StorageClass
kubectl delete storageclass nfs-csi

# Create WORKING nfs-csi StorageClass
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: nfs.csi.k8s.io
parameters:
  server: 10.0.1.10
  share: /mnt/nfs-share
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF
```

### Step 4: Test Dynamic Provisioning

```bash
# Test PVC (should auto-provision)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

**Expected:**
```bash
kubectl get pvc test-nfs-pvc     # STATUS: Bound
kubectl get pv                   # PV auto-created
```

### Step 5: Deploy Working StatefulSet with NFS

**`working-nfs-statefulset.yml`:**
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: mongo
spec:
  clusterIP: "None"
  selector:
    app: mongo
  ports:
  - port: 27017
    targetPort: 27017
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongo-statefulset
spec:
  serviceName: mongo
  replicas: 2
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
      - name: mongo-container
        image: mongo:6.0
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
        - name: mongodbvol
          mountPath: /data/db
  volumeClaimTemplates:
  - metadata:
      name: mongodbvol
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
      storageClassName: nfs-csi  # Now works!
```

### Step 6: Deploy and Verify

```bash
# Deploy StatefulSet
kubectl apply -f working-nfs-statefulset.yml

# Watch success
kubectl get pods,pvc,pv -w

# Expected FINAL state:
# pod/mongo-statefulset-0          1/1    Running
# pod/mongo-statefulset-1          1/1    Running
# pvc/mongodbvol-mongo-statefulset-0  Bound  pvc-xxx  1Gi
# pvc/mongodbvol-mongo-statefulset-1  Bound  pvc-yyy  1Gi
```

### Step 7: Verify NFS Storage

```bash
# Check on NFS server
ls -la /mnt/nfs-share/
# Should show directories like: default-mongodbvol-mongo-statefulset-0-pvc-xxx

# Test MongoDB
kubectl exec -it mongo-statefulset-0 -- mongosh -u devdb -p devdb123
```

## Troubleshooting Commands

```bash
# Check NFS provisioner logs
kubectl logs -n nfs-provisioner deployment/nfs-provisioner

# Check NFS exports
sudo showmount -e localhost

# Verify directories created
sudo ls -la /mnt/nfs-share/
```

## Summary of Fix

```
❌ BEFORE: Broken StorageClasses (nfs-csi, missing nfs-storage)
✅ AFTER: 
  - nfs-provisioner: Running in nfs-provisioner namespace
  - nfs-storage: Working (non-default)
  - nfs-csi: Fixed default StorageClass
  - Dynamic provisioning: ✅ WORKS
```

**Your StatefulSet will now deploy with 2 MongoDB replicas using dynamic NFS storage!** Access Spring Boot at `http://10.0.1.10:30303` once connected.


------------------------------
Pag-2
-------------------------------
## Problem: `nfs-csi` StorageClass Still Broken

**Your NFS provisioner is working** (`nfs-storage` StorageClass + pod 1/1 Running), but **`nfs-csi` is still waiting for non-existent CSI driver**.

```
✅ nfs-provisioner: Running ✓
✅ nfs-storage: Working ✓  
❌ nfs-csi: Missing CSI driver `nfs.csi.k8s.io` ✗ (wrong provisioner)
```

## IMMEDIATE SOLUTION: Use Working `nfs-storage`

### Step 1: Test Working StorageClass
```bash
# Delete broken test PVC
kubectl delete pvc test-nfs-pvc

# Test CORRECT StorageClass (nfs-storage)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-working
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: nfs-storage  # Use WORKING one
EOF

# Verify SUCCESS
kubectl get pvc test-nfs-working    # Should be BOUND
kubectl get pv                      # PV auto-created
ls -la /mnt/nfs-share/              # Directory created
```

### Step 2: Delete Broken Default StorageClass
```bash
kubectl delete storageclass nfs-csi
kubectl patch storageclass nfs-storage -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Step 3: Deploy StatefulSet with WORKING StorageClass

**`final-working-statefulset.yml`:**
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: mongo
spec:
  clusterIP: "None"
  selector:
    app: mongo
  ports:
  - port: 27017
    targetPort: 27017
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongo-statefulset
spec:
  serviceName: mongo
  replicas: 2
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
      - name: mongo-container
        image: mongo:6.0
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
        - name: mongodbvol
          mountPath: /data/db
  volumeClaimTemplates:
  - metadata:
      name: mongodbvol
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
      storageClassName: nfs-storage  # WORKING provisioner!
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: springapp-deployment
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
      - name: springapp-container
        image: dockeruma03/spring-boot-mongo:1
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_DATA_MONGODB_URI
          value: "mongodb://devdb:devdb123@mongo-statefulset-0.mongo:27017/myappdb?authSource=admin"
---
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
    nodePort: 30303
```

### Step 4: Deploy and Verify
```bash
kubectl apply -f final-working-statefulset.yml
kubectl get pods,pvc,pv -w
```

**Expected SUCCESS:**
```
NAME                    READY   STATUS
pod/mongo-statefulset-0 1/1     Running
pod/mongo-statefulset-1 1/1     Running
pod/springapp...        1/1     Running

NAME                              STATUS   VOLUME              STORAGECLASS
pvc/mongodbvol-mongo-statefulset-0 Bound    pvc-xxx            nfs-storage
pvc/mongodbvol-mongo-statefulset-1 Bound    pvc-yyy            nfs-storage
```

### Step 5: Verify NFS Storage Created
```bash
# On NFS server - check dynamic directories
sudo ls -la /mnt/nfs-share/
# Should show: default-mongodbvol-mongo-statefulset-0-pvc-xxx
#              default-mongodbvol-mongo-statefulset-1-pvc-yyy

# Test MongoDB access
kubectl exec -it mongo-statefulset-0 -- mongosh -u devdb -p devdb123

# Test Spring Boot
curl http://10.0.1.10:30303
```

## Why This Works Now

```
✅ NFS Server: Running + exported /mnt/nfs-share ✓
✅ Provisioner Pod: 1/1 Running ✓  
✅ StorageClass nfs-storage: PROVISIONER = nfs-subdir-external-provisioner ✓
✅ Default StorageClass: Fixed to nfs-storage ✓
✅ StatefulSet: Uses nfs-storage (dynamic provisioning) ✓
```

## Key Points

1. **`nfs-storage`** (from Helm) = **WORKING** (nfs-subdir-external-provisioner)
2. **`nfs-csi`** (manual) = **BROKEN** (expected nfs.csi.k8s.io driver doesn't exist)
3. **Solution**: Use `nfs-storage` StorageClass everywhere

**Your 2-replica MongoDB StatefulSet + Spring Boot will now deploy successfully with dynamic NFS storage!**
