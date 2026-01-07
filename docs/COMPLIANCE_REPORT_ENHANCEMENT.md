# Azure Policy Compliance Report - Enhanced Workflow

## What Changed

### 1. Intelligent Waiting for Compliance Data
The workflow test now detects when Azure Policy compliance data isn't available yet and offers three options:

**[W] Wait and check now** - Re-queries Azure Policy immediately
**[L] Wait Later** - Keep resources alive and re-run compliance report manually  
**[C] Continue** - Proceed with testing, ignore missing compliance data

### 2. New Standalone Script: Regenerate-ComplianceReport.ps1
Re-generates ONLY the compliance report without re-running the entire workflow.

**Usage:**
```powershell
.\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId 20260107-130310

# With resource group filter:
.\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId 20260107-130310 -ResourceGroupName rg-policy-keyvault-test
```

### 3. Helpful Reminders
- Cleanup prompt now reminds users they can keep resources to wait for compliance data
- Script provides exact command to re-run compliance report
- Updated documentation in QUICK_START.md with troubleshooting steps

## Workflow Behavior

### Before (Old):
1. Assign policies
2. Wait 5 seconds (not enough!)
3. Generate compliance report (always shows 0 evaluations)
4. Continue with remediation
5. User has no way to get real compliance data

### After (New):
1. Assign policies  
2. Wait 5 seconds
3. Generate compliance report  
4. **DETECT if 0 evaluations found**
5. **PAUSE and offer options:**
   - [W] Re-query now
   - [L] Keep resources, re-run later with standalone script
   - [C] Continue anyway
6. At cleanup prompt, remind about re-generation option
7. User can run: `.\scripts\Regenerate-ComplianceReport.ps1` anytime

## Files Modified

1. **scripts/Run-ForegroundWorkflowTest.ps1**
   - Added compliance data detection after Step 3.5
   - Added interactive pause with W/L/C options
   - Updated cleanup prompt with reminder

2. **scripts/Regenerate-ComplianceReport.ps1** (NEW)
   - Standalone script to re-query Azure Policy
   - Regenerates HTML/JSON/CSV compliance reports
   - Shows helpful tips if still no data available

3. **docs/QUICK_START.md**
   - Updated troubleshooting section
   - Added examples for Regenerate-ComplianceReport.ps1
   - Explained 3 options for handling delayed compliance data

## Testing Recommendations

### Scenario 1: Fast Testing (Ignore Compliance Data)
- Run workflow test
- At policy validation pause, choose [C] Continue
- At cleanup prompt, choose [Y] Yes to remove resources
- Result: Fast test cycle, compliance report will be placeholder

### Scenario 2: Wait for Real Compliance Data (Immediate)
- Run workflow test  
- At policy validation pause, choose [W] Wait
- Script re-queries Azure Policy
- If data available, compliance report updates
- If still not ready, try [L] instead

### Scenario 3: Wait for Real Compliance Data (Later)
- Run workflow test
- At policy validation pause, choose [L] Wait Later
- At cleanup prompt, choose [N] No (keep resources)
- Wait 15-30 minutes
- Run: `.\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId <timestamp>`
- Open updated compliance report
- Manually cleanup when done

## Next Steps

Test the new workflow:
```powershell
.\scripts\Run-ForegroundWorkflowTest.ps1
# When prompted about compliance data, try [W] or [L] options
```

If you kept resources, test standalone regeneration:
```powershell
.\scripts\Regenerate-ComplianceReport.ps1 -WorkflowRunId 20260107-130310
```
