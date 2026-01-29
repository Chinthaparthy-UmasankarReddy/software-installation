## Problem Analysis

Your MongoDB StatefulSet pod (`mongodb-0`) is **Pending** because the `mongo-storage-mongodb-0` PVC is stuck in **Pending** state. Key issues from `kubectl describe`:

1. **StorageClass Mismatch**: Error shows `storageclass.storage.k8s.io "manual" not found`
2. **PV Conflict**: `mongo-pv` is already **Bound** to `mongo-pvc` (standalone PVC)
3. **StatefulSet PVC**: Needs its own dynamically provisioned storage via `volumeClaimTemplates`

Spring Boot pods are running fine (2/2 READY) - only MongoDB is blocked.

## Immediate Fix - Clean Deployment

### Step 1: Delete Conflicting Resources
```bash
# Delete everything to start fresh
kubectl delete -f complete-app.yml

# Verify cleanup
kubectl get all,pvc,pv
```

### Step 2: **Use ONLY volumeClaimTemplates** (Remove standalone PV/PVC)
Replace your `complete-app.yml` with this **corrected version**:

```yaml
---
# 1. MongoDB StatefulSet ONLY (volumeClaimTemplates creates PVC automatically)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
spec:
  serviceName: mongosvc
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - name: mongodb
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
  volumeClaimTemplates:
  - metadata:
      name: mongo-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
      # Remove storageClassName - let Kubernetes use default

---
# 2. MongoDB Headless Service
apiVersion: v1
kind: Service
metadata:
  name: mongosvc
spec:
  clusterIP: None
  selector:
    app: mongo
  ports:
  - port: 27017
    targetPort: 27017

---
# 3. MongoDB ClusterIP Service
apiVersion: v1
kind: Service
metadata:
  name: mongo-cluster-svc
spec:
  type: ClusterIP
  selector:
    app: mongo
  ports:
  - port: 27017
    targetPort: 27017

---
# 4. Spring Boot Deployment (Working)
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
        - name: SPRING_DATA_MONGODB_URI
          value: "mongodb://devdb:devdb123@mongo-cluster-svc:27017/myappdb?authSource=admin"
        - name: SPRING_DATA_MONGODB_DATABASE
          value: "myappdb"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"

---
# 5. Spring Boot Service
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

### Step 3: Deploy Fixed Version
```bash
# Save as complete-app-fixed.yml
kubectl apply -f complete-app-fixed.yml
```

### Step 4: Verify Success
```bash
# Watch pods become ready
kubectl get pods -w

# Check PVCs (StatefulSet creates its own)
kubectl get pvc

# Expected output:
# NAME                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# mongo-storage-mongodb-0       Bound    pvc-xxx                                   5Gi        RWO            standard       30s
```

## Alternative: Manual PV for StatefulSet

If you want **persistent hostPath storage**, create a **dynamic PV** for StatefulSet PVC:

```bash
# Create second PV specifically for StatefulSet
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongo-stateful-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""  # Empty = default
  hostPath:
    path: /mnt/mongo-data
EOF
```

## Expected Final Status
```
NAME                    READY   STATUS
pod/mongodb-0          1/1     Running
pod/springapp...       1/1     Running
pod/springapp...       1/1     Running

NAME                    STATUS   VOLUME
pvc/mongo-storage...   Bound    pvc-xxx
```

## Test Application
```bash
# Get node IP
kubectl get nodes -o wide

# Access app
curl http://10.0.1.10:32577

# Check MongoDB connection in Spring logs
kubectl logs deployment/springappdeployment
```

**Root Cause**: Standalone PV/PVC conflicted with StatefulSet's `volumeClaimTemplates`. Fixed version uses **StatefulSet-only** approach with automatic PVC provisioning. Your Spring Boot will connect successfully once MongoDB starts!
