## StatefulSet vs Deployment: MongoDB Comparison

### Key Differences Table

| Feature | Deployment | StatefulSet |
|---------|------------|-------------|
| **Pod Naming** | Random (`mongodb-deployment-abc123`) | Predictable (`mongodb-0`, `mongodb-1`) |
| **Pod Identity** | Replaceable, interchangeable | Sticky, unique identity preserved |
| **Storage** | Shared PVC across pods | Unique PVC per pod (`mongo-storage-mongodb-0`) |
| **Scaling** | Simultaneous pod creation | Sequential pod creation (0→1→2) |
| **Service** | Regular ClusterIP | Requires Headless Service |
| **Use Case** | Stateless apps | Stateful apps (databases) |

## Complete StatefulSet Implementation

Save as `mongodb-statefulset.yml`:

```yaml
---
# 1. MongoDB StatefulSet with Automatic PVC Creation
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
spec:
  serviceName: mongosvc  # Required: Links to headless service
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
  volumeClaimTemplates:  # Creates unique PVC per pod
  - metadata:
      name: mongo-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
      storageClassName: ""  # Uses default storage class

---
# 2. Headless Service (REQUIRED for StatefulSet)
apiVersion: v1
kind: Service
metadata:
  name: mongosvc
spec:
  clusterIP: None  # Headless = DNS A records for each pod
  selector:
    app: mongo
  ports:
  - port: 27017
    targetPort: 27017

---
# 3. ClusterIP Service (For Spring Boot access)
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
```

## Complete Deployment Implementation

Save as `mongodb-deployment.yml`:

```yaml
---
# 1. Manual PV + PVC
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongo-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/mongo-data

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual

---
# 2. MongoDB Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb-deployment
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
      volumes:
      - name: mongo-storage
        persistentVolumeClaim:
          claimName: mongo-pvc

---
# 3. Simple ClusterIP Service
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
```

## Step-by-Step Comparison Deployment

### 1. Clean Previous Deployments
```bash
kubectl delete all --all -l app=mongo
kubectl delete all --all -l app=springapp
kubectl delete pv,pvc --all
sudo rm -rf /mnt/mongo-data/*
sudo mkdir -p /mnt/mongo-data
sudo chown 999:999 /mnt/mongo-data
```

### 2A. Deploy MongoDB as Deployment (Simple)
```bash
kubectl apply -f mongodb-deployment.yml
```

**Verify Deployment:**
```bash
kubectl get pods          # mongodb-deployment-xyz-abc123
kubectl get pvc,pv        # mongo-pvc → Bound → mongo-pv
kubectl get svc           # mongo-cluster-svc (regular service)
```

### 2B. Deploy MongoDB as StatefulSet (Production)
```bash
kubectl delete -f mongodb-deployment.yml
kubectl apply -f mongodb-statefulset.yml
```

**Verify StatefulSet:**
```bash
kubectl get pods               # mongodb-0 (predictable name)
kubectl get pvc                # mongo-storage-mongodb-0 (unique PVC)
kubectl get statefulset        # mongodb → 1/1 ready
kubectl get svc                # mongosvc (headless) + mongo-cluster-svc
```

### 3. Deploy Spring Boot (Same for Both)
```bash
cat <<EOF | kubectl apply -f -
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
    nodePort: 32577
EOF
```

### 4. Test Both Scenarios

**Check MongoDB Status:**
```bash
# Deployment
kubectl get pods -l app=mongo          # Random pod name
kubectl logs deployment/mongodb-deployment

# StatefulSet  
kubectl get pods -l app=mongo          # mongodb-0
kubectl logs statefulset/mongodb
```

**Test Application:**
```bash
curl http://10.0.1.10:32577
kubectl logs deployment/springappdeployment
```

### 5. Scale Test (Key Difference)

**Deployment Scaling:**
```bash
kubectl scale deployment mongodb-deployment --replicas=2
# Creates: mongodb-deployment-xyz-abc123, mongodb-deployment-xyz-def456
# Both pods compete for SAME mongo-pvc → FAILURE
```

**StatefulSet Scaling:**
```bash
kubectl scale statefulset mongodb --replicas=2
# Creates: mongodb-0, mongodb-1
# Each gets unique PVC: mongo-storage-mongodb-0, mongo-storage-mongodb-1
```

## Summary Status Comparison

| Resource | Deployment | StatefulSet |
|----------|------------|-------------|
| **Pod Names** | `mongodb-deployment-abc123` | `mongodb-0` |
| **PVCs** | `mongo-pvc` (shared) | `mongo-storage-mongodb-0` (unique) |
| **Services** | 1x ClusterIP | 1x Headless + 1x ClusterIP |
| **Scaling** | ❌ Shared storage conflict | ✅ Unique storage per pod |
| **Data Safety** | Risky for production | Production-ready |

**Use Deployment** for simple dev/testing. **Use StatefulSet** for production MongoDB with guaranteed data persistence and scalability.
