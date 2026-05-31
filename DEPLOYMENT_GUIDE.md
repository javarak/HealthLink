# 🚀 HealthLink Deployment Guide - Google Cloud Platform

This guide walks you through deploying HealthLink to Google Cloud Run using the existing GitHub Actions workflow.

## 📋 Prerequisites

- GitHub repository with your code
- Google Cloud Platform account
- `gcloud` CLI installed (you already have this)
- Docker installed locally (for testing)

---

## 🔧 Step 1: Configure Google Cloud Platform

### 1.1 Set Project Variables
```bash
# Set your project ID (you're already using this one)
export PROJECT_ID="gen-lang-client-0039141033"
export REGION="us-central1"
export SERVICE_NAME="healthlink"

gcloud config set project $PROJECT_ID
```

### 1.2 Enable Required APIs
```bash
# Enable necessary GCP services
gcloud services enable \
  run.googleapis.com \
  containerregistry.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com
```

### 1.3 Create Service Account
```bash
# Create service account for GitHub Actions
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Service Account" \
  --project=$PROJECT_ID

# Get the service account email
export SA_EMAIL="github-actions@${PROJECT_ID}.iam.gserviceaccount.com"
echo "Service Account: $SA_EMAIL"
```

### 1.4 Grant Required Permissions
```bash
# Grant Cloud Run Admin role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.admin"

# Grant Service Account User role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

# Grant Storage Admin for Container Registry
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.admin"

# Grant Secret Manager Secret Accessor
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/secretmanager.secretAccessor"
```

### 1.5 Create Service Account Key
```bash
# Create and download JSON key
gcloud iam service-accounts keys create github-sa-key.json \
  --iam-account=$SA_EMAIL

# Display the key content (you'll need this for GitHub)
cat github-sa-key.json
```

**⚠️ IMPORTANT:** Keep this JSON file secure! You'll add it to GitHub secrets.

---

## 🔐 Step 2: Store Secrets in GCP Secret Manager

```bash
# Create GEMINI_API_KEY secret
echo -n "YOUR_GEMINI_API_KEY_HERE" | \
  gcloud secrets create GEMINI_API_KEY \
  --data-file=- \
  --replication-policy="automatic"

# Create PINECONE_API_KEY secret
echo -n "YOUR_PINECONE_API_KEY_HERE" | \
  gcloud secrets create PINECONE_API_KEY \
  --data-file=- \
  --replication-policy="automatic"

# Verify secrets were created
gcloud secrets list
```

---

## 🔑 Step 3: Configure GitHub Secrets

### 3.1 Navigate to GitHub Repository Settings
1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

### 3.2 Add Required Secrets

Add these secrets one by one:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `GCP_PROJECT_ID` | `gen-lang-client-0039141033` | Your GCP project ID |
| `GCP_SA_KEY` | Content of `github-sa-key.json` | Service account JSON key (entire file content) |
| `GEMINI_API_KEY` | Your Gemini API key | For testing in GitHub Actions |
| `PINECONE_API_KEY` | Your Pinecone API key | For testing in GitHub Actions |

### 3.3 How to Add the Service Account Key

```bash
# Copy the entire JSON file content
cat github-sa-key.json
```

Copy everything from `{` to `}` including the braces, then:
1. In GitHub: **New repository secret**
2. Name: `GCP_SA_KEY`
3. Value: Paste the entire JSON content
4. Click **Add secret**

---

## 🐳 Step 4: Test Docker Build Locally (Optional)

Before pushing, verify your Docker build works:

```bash
# Build the image
docker build -t healthlink:local .

# Test run locally
docker run -p 8000:8000 \
  -e GEMINI_API_KEY="your-key" \
  -e PINECONE_API_KEY="your-key" \
  -e DATABASE_URL="sqlite:///./data/healthlink.db" \
  -e SECRET_KEY="test-secret" \
  healthlink:local

# Test the API
curl http://localhost:8000/health
```

---

## 🚀 Step 5: Deploy Using GitHub Actions

### 5.1 Push to GitHub

```bash
# Initialize git if not already done
git init
git add .
git commit -m "Initial commit with CI/CD pipeline"

# Add your GitHub repository as remote
git remote add origin https://github.com/YOUR_USERNAME/healthlink.git

# Create main branch and push
git branch -M main
git push -u origin main
```

### 5.2 Automatic Deployment

Once pushed to the `main` branch:
1. GitHub Actions automatically triggers
2. Runs tests and linting
3. Builds Docker image
4. Pushes to Google Container Registry
5. Deploys to Cloud Run
6. Runs health check

### 5.3 Monitor Deployment

Watch the deployment progress:
1. Go to your GitHub repository
2. Click **Actions** tab
3. Click on the running workflow
4. Monitor each job's progress

---

## 🔍 Step 6: Verify Deployment

### 6.1 Get Service URL

```bash
# Get the deployed service URL
gcloud run services describe healthlink \
  --region=us-central1 \
  --format='value(status.url)'
```

### 6.2 Test Deployed Service

```bash
# Get the URL
export SERVICE_URL=$(gcloud run services describe healthlink \
  --region=us-central1 \
  --format='value(status.url)')

echo "Service URL: $SERVICE_URL"

# Test health endpoint
curl $SERVICE_URL/health

# Test API docs
curl $SERVICE_URL/docs
```

### 6.3 Open in Browser

```bash
# Open the service in browser
start $SERVICE_URL
# or
start $SERVICE_URL/docs
```

---

## 📊 Step 7: View Logs and Monitor

### View Real-time Logs
```bash
# Stream logs from Cloud Run
gcloud run services logs read healthlink \
  --region=us-central1 \
  --limit=50 \
  --follow
```

### View in GCP Console
```bash
# Open Cloud Run console
gcloud run services describe healthlink \
  --region=us-central1 \
  --format='value(status.url)' | xargs start
```

Or visit: https://console.cloud.google.com/run?project=gen-lang-client-0039141033

---

## 🔄 Step 8: Make Updates

### Deploy Updates
```bash
# Make your code changes
# Commit and push to main branch
git add .
git commit -m "Update feature X"
git push origin main

# GitHub Actions automatically deploys the changes!
```

### Manual Deployment Trigger
1. Go to GitHub → Actions
2. Click "Deploy to Google Cloud Run"
3. Click "Run workflow"
4. Select branch and click "Run workflow"

---

## 🛠️ Troubleshooting

### Issue 1: Health Check Fails

The deploy.yaml checks `/api/v1/health`, but your app might use `/health`:

```bash
# Test which endpoint works
curl $SERVICE_URL/health
curl $SERVICE_URL/api/v1/health
```

If `/health` works, you can update deploy.yaml line 127 or update your API to support both endpoints.

### Issue 2: Secrets Not Found

```bash
# Verify secrets exist
gcloud secrets list

# Check secret versions
gcloud secrets versions list GEMINI_API_KEY
gcloud secrets versions list PINECONE_API_KEY
```

### Issue 3: Build Fails

```bash
# Check GitHub Actions logs
# View the error in the Actions tab

# Test Docker build locally
docker build -t healthlink:test .
```

### Issue 4: Permission Denied

```bash
# Re-check service account permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SA_EMAIL}"
```

### Issue 5: Service Not Responding

```bash
# Check service status
gcloud run services describe healthlink --region=us-central1

# Check revisions
gcloud run revisions list --service=healthlink --region=us-central1

# View detailed logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=healthlink" \
  --limit=50 \
  --format=json
```

---

## 🔐 Security Best Practices

### 1. Rotate Service Account Key Regularly
```bash
# Create new key
gcloud iam service-accounts keys create new-key.json \
  --iam-account=$SA_EMAIL

# Delete old key (get KEY_ID from list)
gcloud iam service-accounts keys list --iam-account=$SA_EMAIL
gcloud iam service-accounts keys delete KEY_ID --iam-account=$SA_EMAIL
```

### 2. Use Least Privilege
Only grant necessary permissions to service accounts.

### 3. Enable VPC Connector (Optional)
For production, consider using VPC for private networking.

---

## 📈 Scaling Configuration

### Update Cloud Run Settings
```bash
# Modify scaling settings
gcloud run services update healthlink \
  --region=us-central1 \
  --min-instances=1 \
  --max-instances=20 \
  --concurrency=100 \
  --cpu=2 \
  --memory=4Gi
```

---

## 💰 Cost Optimization

### Current Configuration
- Min instances: 0 (scales to zero when not in use)
- Max instances: 10
- Memory: 2Gi
- CPU: 2

### Estimated Costs
- **Development**: ~$0-5/month (with scale to zero)
- **Production (moderate traffic)**: ~$20-50/month
- **High traffic**: Based on actual usage

### Monitor Costs
```bash
# View billing
gcloud billing accounts list
```

Visit: https://console.cloud.google.com/billing

---

## 🎯 Quick Reference Commands

```bash
# Deploy from local machine (if needed)
gcloud run deploy healthlink \
  --image gcr.io/gen-lang-client-0039141033/healthlink:latest \
  --region us-central1 \
  --platform managed

# View service details
gcloud run services describe healthlink --region us-central1

# View logs
gcloud run services logs read healthlink --region us-central1 --limit 100

# Update environment variables
gcloud run services update healthlink \
  --region us-central1 \
  --update-env-vars "LOG_LEVEL=DEBUG"

# List all deployed services
gcloud run services list

# Delete service
gcloud run services delete healthlink --region us-central1
```

---

## ✅ Deployment Checklist

- [ ] GCP project set up and APIs enabled
- [ ] Service account created with proper permissions
- [ ] Service account key downloaded
- [ ] Secrets stored in GCP Secret Manager
- [ ] GitHub secrets configured (4 secrets)
- [ ] Docker build tested locally
- [ ] Code pushed to GitHub main branch
- [ ] GitHub Actions workflow completed successfully
- [ ] Service URL accessible
- [ ] Health check passes
- [ ] API documentation accessible at /docs

---

## 📞 Support

If you encounter issues:

1. **Check GitHub Actions logs**: Repository → Actions → Failed workflow
2. **Check Cloud Run logs**: 
   ```bash
   gcloud run services logs read healthlink --region us-central1 --limit 100
   ```
3. **Verify configuration**:
   ```bash
   gcloud run services describe healthlink --region us-central1
   ```

---

## 🎉 Success!

Once deployed, your HealthLink application will be available at:
```
https://healthlink-XXXXXXXXX-uc.a.run.app
```

The URL will be displayed in:
- GitHub Actions workflow output
- GCP Cloud Run console
- Command: `gcloud run services describe healthlink --region us-central1 --format='value(status.url)'`

**Next Steps:**
- Set up custom domain (optional)
- Configure CDN (optional)
- Set up monitoring and alerts
- Configure backup strategy
