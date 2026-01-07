#!/usr/bin/env pwsh
# Simple, robust AI Cost Calculator (clean rebuild)
# - accepts decimal inputs
# - provides menu modes for today's input
# - computes current and today hourly rates, projections, recommendation, ASCII graph

function Parse-HHMM($s) {
    try { return [datetime]::ParseExact($s, 'HH:mm', $null) }
    catch { return $null }
}

function ToHours($dt) { return $dt.Hour + ($dt.Minute / 60.0) }

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Config
$BasePlanPrice = 10.00
$OveragePricePerRequest = 0.04
$MonthlyBudget = 20.00
$HoursPerWorkday = 8.0
$DefaultBasePlanRequests = 300

Write-Host "Start time (HH:mm):" -NoNewline; $startInput = Read-Host
$startDt = Parse-HHMM $startInput
if (-not $startDt) { Write-Host 'Invalid start time'; exit 1 }

Write-Host "Current clock time (HH:mm) or leave blank for system time:" -NoNewline; $currentTimeInput = Read-Host
if ([string]::IsNullOrWhiteSpace($currentTimeInput)) {
    $currentDt = Get-Date
} else {
    $currentDt = Parse-HHMM $currentTimeInput
    if (-not $currentDt) { Write-Host 'Invalid current time'; exit 1 }
}

Write-Host "Requests month-to-date (number, decimals allowed):" -NoNewline; $requestsMonthInput = Read-Host
$requestsMonthVal = 0.0
if (-not [double]::TryParse($requestsMonthInput, [ref]$requestsMonthVal)) { Write-Host 'Invalid number for requests month-to-date'; exit 1 }
$requestsMonth = [double]$requestsMonthVal

Write-Host "Full date (YYYY-MM-DD):" -NoNewline; $dateInput = Read-Host
try { $givenDate = [datetime]::ParseExact($dateInput,'yyyy-MM-dd',$null) } catch { Write-Host 'Invalid date format'; exit 1 }

Write-Host "Base plan requests for this month (leave blank for $DefaultBasePlanRequests):" -NoNewline; $bpi = Read-Host
if ([string]::IsNullOrWhiteSpace($bpi)) { $basePlanRequests = $DefaultBasePlanRequests } else { $bpv=0; if (-not [int]::TryParse($bpi,[ref]$bpv)) { Write-Host 'Invalid integer for base plan'; exit 1 } ; $basePlanRequests=[int]$bpv }

# Compute workdays in month (simple: exclude weekends only)
function Get-WorkdaysInMonth($year,$month) {
    $cnt=0; $days=[datetime]::DaysInMonth($year,$month)
    for ($d=1;$d -le $days;$d++) { $dt=Get-Date -Year $year -Month $month -Day $d; if ($dt.DayOfWeek -ne 'Saturday' -and $dt.DayOfWeek -ne 'Sunday') { $cnt++ } }
    return $cnt
}

$year=$givenDate.Year; $month=$givenDate.Month; $dayOfMonth=$givenDate.Day
$workdaysInMonth = Get-WorkdaysInMonth $year $month

# normalize start/current to givenDate
$startRef = Get-Date -Year $givenDate.Year -Month $givenDate.Month -Day $givenDate.Day -Hour $startDt.Hour -Minute $startDt.Minute -Second 0
$currentRef = Get-Date -Year $givenDate.Year -Month $givenDate.Month -Day $givenDate.Day -Hour $currentDt.Hour -Minute $currentDt.Minute -Second 0
$curH = ToHours($currentRef)
$startH = ToHours($startRef)
$elapsedSoFar = [math]::Max(0.0, $curH - $startH)
$hoursRemainingToday = [math]::Max(0.0, $HoursPerWorkday - $elapsedSoFar)

# menu
Write-Host ""; Write-Host "Select input mode for today's usage:" -ForegroundColor Cyan
Write-Host "  1) Month-to-date only"; Write-Host "  2) Provide month-to-date at start of day"; Write-Host "  3) Provide today's current count"
$mode = Read-Host "Enter 1/2/3 (default 1)"
if ([string]::IsNullOrWhiteSpace($mode)) { $mode = '1' }

$requestsToday = 0.0; $todayHourlyRate = $null; $projectedMonthlyFromTodayRate = $null
if ($mode -eq '2') {
    $ms = Read-Host 'Month-to-date at start of day (number)'
    $mv=0.0; if (-not [double]::TryParse($ms,[ref]$mv)) { Write-Host 'Invalid number' ; exit 1 }
    $requestsToday = [math]::Max(0.0, $requestsMonth - $mv)
} elseif ($mode -eq '3') {
    $cur = Read-Host "Today's current count (number)"
    $cv=0.0; if (-not [double]::TryParse($cur,[ref]$cv)) { Write-Host 'Invalid number' ; exit 1 }
    $requestsToday = [math]::Max(0.0, $cv - $requestsMonth)
    if ($elapsedSoFar -gt 0) { $todayHourlyRate = $requestsToday / $elapsedSoFar; $projectedMonthlyFromTodayRate = $todayHourlyRate * $HoursPerWorkday * $workdaysInMonth }
}

# calculations
$workedFullDays = [math]::Max(0, ([math]::Floor(($dayOfMonth-1)/1))) # simple: days before today
$workedHoursSoFar = ($workedFullDays * $HoursPerWorkday) + $elapsedSoFar
if ($workedHoursSoFar -le 0) { $currentHourlyRate = 0 } else { $currentHourlyRate = $requestsMonth / $workedHoursSoFar }
$projectedMonthlyFromCurrentRate = $currentHourlyRate * $HoursPerWorkday * $workdaysInMonth

$allowedOverage = [math]::Max(0.0, $MonthlyBudget - $BasePlanPrice)
$allowedExtraRequests = [math]::Floor($allowedOverage / $OveragePricePerRequest)
$monthlyTargetRequests = $basePlanRequests + $allowedExtraRequests
$remainingMonthlyRequests = [math]::Max(0.0, $monthlyTargetRequests - $requestsMonth)

$daysLeftWorking = [math]::Max(0, $workdaysInMonth - [math]::Floor($dayOfMonth))
if ($daysLeftWorking -gt 0) { $projectedDailyNeeded = [math]::Ceiling($remainingMonthlyRequests / $daysLeftWorking) } else { $projectedDailyNeeded = $remainingMonthlyRequests }

$todayRemainingRequests = [math]::Max(0.0, $projectedDailyNeeded - $requestsToday)
if ($hoursRemainingToday -gt 0) { $projectedHourlyNeededToday = [math]::Ceiling($todayRemainingRequests / $hoursRemainingToday) } else { $projectedHourlyNeededToday = 0 }

# projected costs
if ($projectedMonthlyFromCurrentRate -le $basePlanRequests) { $projectedCostFromCurrentRate = $BasePlanPrice } else { $projectedCostFromCurrentRate = $BasePlanPrice + (($projectedMonthlyFromCurrentRate - $basePlanRequests) * $OveragePricePerRequest) }
if ($projectedMonthlyFromTodayRate -ne $null) { if ($projectedMonthlyFromTodayRate -le $basePlanRequests) { $projectedCostFromTodayRate = $BasePlanPrice } else { $projectedCostFromTodayRate = $BasePlanPrice + (($projectedMonthlyFromTodayRate - $basePlanRequests) * $OveragePricePerRequest) } } else { $projectedCostFromTodayRate = $null }

# recommendation
$remainingWorkingHours = ($daysLeftWorking * $HoursPerWorkday) + $hoursRemainingToday
if ($remainingWorkingHours -le 0) { $allowedHourlyRateForRemaining = 0 } else { $allowedHourlyRateForRemaining = $remainingMonthlyRequests / $remainingWorkingHours }

# small helper for bars
function Get-Bar([double]$val, [double]$max) {
    $width = 40
    if ($max -le 0 -or [double]::IsNaN($max) -or [double]::IsInfinity($max)) { $max = 1.0 }
    $ratio = 0.0
    if ($val -gt 0) { $ratio = $val / $max }
    if ($ratio -lt 0) { $ratio = 0 }
    if ($ratio -gt 1) { $ratio = 1 }
    $len = [int]([math]::Round($ratio * $width))
    return ('=' * $len) + (' ' * ($width - $len))
}

# graph max
if ($todayHourlyRate -ne $null) { $todayVal = [double]$todayHourlyRate } else { $todayVal = 0.0 }
$graphMax = [math]::Max(1.0, [math]::Max($allowedHourlyRateForRemaining, [math]::Max($currentHourlyRate, $todayVal)))

# output
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "==== Forecast Summary ====" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Given date: $($givenDate.ToString('yyyy-MM-dd'))" -ForegroundColor Yellow
Write-Host "Start: $($startDt.ToString('HH:mm'))   Current: $($currentRef.ToString('HH:mm'))   Elapsed hrs: $([math]::Round($elapsedSoFar,2))" -ForegroundColor White
Write-Host "Requests month-to-date: $([math]::Round($requestsMonth,2))" -ForegroundColor Green
Write-Host "Requests today (computed): $([math]::Round($requestsToday,2))" -ForegroundColor Green
Write-Host "-- Projections --" -ForegroundColor DarkCyan
Write-Host "Current hourly rate (req/hr): $([math]::Round($currentHourlyRate,2))" -ForegroundColor Yellow
Write-Host "Projected monthly (from current): $([math]::Round($projectedMonthlyFromCurrentRate,0))" -ForegroundColor Yellow
if ($projectedMonthlyFromTodayRate -ne $null) { Write-Host "Today hourly rate (req/hr): $([math]::Round($todayHourlyRate,2))" -ForegroundColor Cyan; Write-Host "Projected monthly (from today): $([math]::Round($projectedMonthlyFromTodayRate,0))" -ForegroundColor Cyan }
Write-Host "Recommendation: keep average <= $([math]::Round($allowedHourlyRateForRemaining,2)) req/hr for remaining hours" -ForegroundColor Green

Write-Host ""; Write-Host "-- Rate Comparison (req/hr) --" -ForegroundColor DarkCyan
Write-Host "Legend: Allowed = allowed avg for remaining hours; Current = month avg; Today = today's run-rate" -ForegroundColor White
Write-Host "Allowed  : [{0}] {1:N2} req/hr" -f (Get-Bar $allowedHourlyRateForRemaining $graphMax), $allowedHourlyRateForRemaining -ForegroundColor Green
Write-Host "Current  : [{0}] {1:N2} req/hr" -f (Get-Bar $currentHourlyRate $graphMax), $currentHourlyRate -ForegroundColor Yellow
if ($todayHourlyRate -ne $null) { $col='Cyan'; if ($todayHourlyRate -gt $allowedHourlyRateForRemaining) { $col='Red' }; Write-Host "Today    : [{0}] {1:N2} req/hr" -f (Get-Bar $todayHourlyRate $graphMax), $todayHourlyRate -ForegroundColor $col }
Write-Host "====================================" -ForegroundColor Cyan

Write-Host "Done." -ForegroundColor Cyan
# forecast_full.ps1
# Prompts:
#  - Start time (HH:mm)
#  - Current clock time (HH:mm) (or leave blank to use system current time)
#  - Requests so far today (number, decimals allowed)
#  - Requests month-to-date (number, decimals allowed)
#  - Full date (YYYY-MM-DD)
$cmpCount = 0
Write-Host "-- Comparisons & Alerts --" -ForegroundColor DarkMagenta
if ($projectedMonthlyFromTodayRate -ne $null) {
    $diff = $projectedMonthlyFromTodayRate - $monthlyTargetRequests
    if ($diff -gt 0) { Write-Host ("ALERT: Today's-rate projection exceeds monthly target by {0:N0} requests" -f $diff) -ForegroundColor Red; $cmpCount++ } else { Write-Host ("OK: Today's-rate projection is {0:N0} requests below monthly target" -f ([math]::Abs($diff))) -ForegroundColor Green }
}

$diffCurrent = $projectedMonthlyFromCurrentRate - $monthlyTargetRequests
if ($diffCurrent -gt 0) { Write-Host ("WARN: Current-rate projection exceeds monthly target by {0:N0} requests" -f $diffCurrent) -ForegroundColor Yellow; $cmpCount++ } else { Write-Host ("OK: Current-rate projection is {0:N0} requests below monthly target" -f ([math]::Abs($diffCurrent))) -ForegroundColor Green }

if ($projectedCostFromTodayRate -ne $null) {
    $costDiff = $projectedCostFromTodayRate - $MonthlyBudget
    if ($costDiff -gt 0) { Write-Host ("ALERT: Projected monthly cost (today's rate) exceeds budget by {0:N2}" -f $costDiff) -ForegroundColor Red; $cmpCount++ } else { Write-Host ("OK: Projected monthly cost (today's rate) is {0:N2} below budget" -f ([math]::Abs($costDiff))) -ForegroundColor Green }
}

$costDiffCur = $projectedCostFromCurrentRate - $MonthlyBudget
if ($costDiffCur -gt 0) { Write-Host ("WARN: Projected monthly cost (current rate) exceeds budget by {0:N2}" -f $costDiffCur) -ForegroundColor Yellow; $cmpCount++ } else { Write-Host ("OK: Projected monthly cost (current rate) is {0:N2} below budget" -f ([math]::Abs($costDiffCur))) -ForegroundColor Green }

if ($cmpCount -eq 0) { Write-Host "No alerts - projections are within targets/budget." -ForegroundColor Cyan }

# Explanation: why Today and Current projections can differ
Write-Host "" -ForegroundColor White
Write-Host "-- Why Today vs Current may differ --" -ForegroundColor DarkMagenta
Write-Host "Today is a short-term run-rate (requests today / elapsed hours)." -ForegroundColor White
Write-Host "Current is the month-to-date average (total requestsMonth / hours worked so far)." -ForegroundColor White
Write-Host "Consequences:" -ForegroundColor Yellow
Write-Host " - A high burst today can make the Today-based projection exceed the monthly target even if the historical Current rate remains below it." -ForegroundColor Yellow
Write-Host " - The Recommendation (Allowed) is computed from remaining requests divided by remaining hours — it's the average rate you must hold from now on to hit the monthly target." -ForegroundColor Yellow
Write-Host " - Use Today for immediate throttling decisions; use Current to understand the overall trend." -ForegroundColor Yellow

# Recommendation: compute allowed average hourly rate for remaining work hours to stay within monthly target
$remainingWorkingHours = ($daysLeftWorking * $HoursPerWorkday) + $hoursRemainingToday
if ($remainingWorkingHours -le 0) { $allowedHourlyRateForRemaining = 0 } else { $allowedHourlyRateForRemaining = $remainingMonthlyRequests / $remainingWorkingHours }
$allowedDailyEquivalent = $allowedHourlyRateForRemaining * $HoursPerWorkday

# Show recommendation and color it red if current hourly rate or today's hourly rate exceed allowable
$recColor = 'Green'
if ($currentHourlyRate -gt $allowedHourlyRateForRemaining) { $recColor = 'Red' }
if ($todayHourlyRate -ne $null -and $todayHourlyRate -gt $allowedHourlyRateForRemaining) { $recColor = 'Red' }
Write-Host ("Recommendation: To stay within monthly target, average ≤ {0:N2} req/hr for remaining work hours (~ {1:N2} req/day)" -f $allowedHourlyRateForRemaining, $allowedDailyEquivalent) -ForegroundColor $recColor

# Per-hour throttle recommendation for the remainder of today
if ($hoursRemainingToday -gt 0) {
    $allowedHourlyToday = $remainingMonthlyRequests / $hoursRemainingToday
    # Conservative suggestion: min of allowedHourlyRateForRemaining and allowedHourlyToday
    $throttleRec = [math]::Min($allowedHourlyRateForRemaining, $allowedHourlyToday)
    $throttleColor = 'Green'
    if ($todayHourlyRate -ne $null -and $throttleRec -lt $todayHourlyRate) { $throttleColor = 'Red' }
    # If the throttle recommendation is effectively the same as the overall allowed hourly rate, skip duplicate line
    if ([math]::Abs($throttleRec - $allowedHourlyRateForRemaining) -ge 0.01) {
        Write-Host ("Throttle recommendation (remainder of today): limit to ≤ {0:N2} req/hr" -f $throttleRec) -ForegroundColor $throttleColor
    }
}

# Simple ASCII bar graph comparing allowed vs current vs today's hourly rates
if ($todayHourlyRate -ne $null) { $todayRateVal = $todayHourlyRate } else { $todayRateVal = 0.0 }
# Nested Max and guard against non-finite values
$graphMax = [math]::Max([math]::Max([math]::Max($allowedHourlyRateForRemaining, $currentHourlyRate), $todayRateVal), 1.0)
if ([double]::IsInfinity($graphMax) -or [double]::IsNaN($graphMax) -or $graphMax -le 0) { $graphMax = 1.0 }

function Get-Bar([double]$val, [double]$max) {
    $width = 40
    if ([double]::IsInfinity($val) -or [double]::IsNaN($val)) { $val = 0.0 }
    if ([double]::IsInfinity($max) -or [double]::IsNaN($max) -or $max -le 0) { $max = 1.0 }
    $ratio = $val / $max
    if ([double]::IsInfinity($ratio) -or [double]::IsNaN($ratio)) { $ratio = 0.0 }
    $len = [int]([math]::Round($ratio * $width))
    if ($len -lt 0) { $len = 0 }
    if ($len -gt $width) { $len = $width }
    return ('=' * $len) + (' ' * ($width - $len))
}

Write-Host "" -ForegroundColor White
Write-Host "-- Rate Comparison (req/hr) --" -ForegroundColor DarkCyan
Write-Host "Legend:" -ForegroundColor DarkCyan
Write-Host "  - Allowed : avg req/hr you can sustain for all remaining work hours (green)" -ForegroundColor Green
Write-Host "  - Current : month-to-date average req/hr so far (yellow)" -ForegroundColor Yellow
Write-Host "  - Today   : current day's run-rate (req/hr) - noisy early; turns red if above Allowed" -ForegroundColor Cyan

$allowedLine = ('Allowed  : [{0}] {1:N2} req/hr' -f (Get-Bar $allowedHourlyRateForRemaining $graphMax), $allowedHourlyRateForRemaining)
Write-Host $allowedLine -ForegroundColor Green
$currentLine = ('Current  : [{0}] {1:N2} req/hr' -f (Get-Bar $currentHourlyRate $graphMax), $currentHourlyRate)
Write-Host $currentLine -ForegroundColor Yellow
if ($todayHourlyRate -ne $null) {
    $todayColor = 'Cyan'
    # Use a small tolerance to avoid floating-point rounding hiding slight overruns
    if ($todayHourlyRate -gt ($allowedHourlyRateForRemaining + 0.0001)) { $todayColor = 'Red' }
    $todayLine = ('Today    : [{0}] {1:N2} req/hr' -f (Get-Bar $todayHourlyRate $graphMax), $todayHourlyRate)
    Write-Host $todayLine -ForegroundColor $todayColor
}
Write-Host "====================================" -ForegroundColor Cyan
    # Veterans Day: Nov 11 (observed)
    $vet = Get-Date -Year $year -Month 11 -Day 11
    $h += (Get-Observed $vet)

    # Thanksgiving: fourth Thursday in November
    $h += (Get-NthWeekdayOfMonth $year 11 'Thursday' 4)

    # Christmas: Dec 25 (observed)
    $xmas = Get-Date -Year $year -Month 12 -Day 25
    $h += (Get-Observed $xmas)

    return $h | Sort-Object
}

function Get-Observed($dt) {
    if ($dt.DayOfWeek -eq 'Saturday') { return $dt.AddDays(-1).Date }
    elseif ($dt.DayOfWeek -eq 'Sunday') { return $dt.AddDays(1).Date }
    else { return $dt.Date }
}

function Get-NthWeekdayOfMonth($year, $month, $weekdayName, $n) {
    $first = Get-Date -Year $year -Month $month -Day 1
    $weekday = [System.DayOfWeek]::Parse([System.DayOfWeek], $weekdayName)
    $offset = ( ([int]$weekday - [int]$first.DayOfWeek) + 7 ) % 7
    $day = 1 + $offset + 7 * ($n - 1)
    return (Get-Date -Year $year -Month $month -Day $day).Date
}

function Get-LastWeekdayOfMonth($year, $month, $weekdayName) {
    $days = [datetime]::DaysInMonth($year, $month)
    for ($d = $days; $d -ge 1; $d--) {
        $dt = Get-Date -Year $year -Month $month -Day $d
        if ($dt.DayOfWeek -eq ([System.DayOfWeek]::Parse([System.DayOfWeek], $weekdayName))) {
            return $dt.Date
        }
    }
}

# --- Workday helpers ---
function Get-WorkdaysInMonth($year, $month, $holidays) {
    $count = 0
    $days = [datetime]::DaysInMonth($year, $month)
    for ($d = 1; $d -le $days; $d++) {
        $dt = Get-Date -Year $year -Month $month -Day $d
        if ($dt.DayOfWeek -ne 'Saturday' -and $dt.DayOfWeek -ne 'Sunday' -and -not ($holidays -contains $dt.Date)) {
            $count++
        }
    }
    return $count
}

function Get-CompletedWorkdays($year, $month, $day, $holidays) {
    $count = 0
    for ($d = 1; $d -le $day; $d++) {
        $dt = Get-Date -Year $year -Month $month -Day $d
        if ($dt.DayOfWeek -ne 'Saturday' -and $dt.DayOfWeek -ne 'Sunday' -and -not ($holidays -contains $dt.Date)) {
            $count++
        }
    }
    return $count
}

# --- Prepare dates/holidays ---
$year = $givenDate.Year
$month = $givenDate.Month
$dayOfMonth = $givenDate.Day

$holidays = Get-USFederalHolidays $year
# Filter holidays to this month for display/calculation convenience
$holThisMonth = $holidays | Where-Object { $_.Month -eq $month }

$workdaysInMonth = Get-WorkdaysInMonth $year $month $holidays
$completedWorkdays = Get-CompletedWorkdays $year $month $dayOfMonth $holidays
$daysLeftWorking = [math]::Max(0, $workdaysInMonth - $completedWorkdays)

# --- End-of-day calculation ---
$startH = ToHours($startDt)
$endOfDayH = $startH + $HoursPerWorkday
if ($endOfDayH -ge 24) { $endOfDayH = 23.999 }
# Build end time as HH:mm
$endHour = [int]([math]::Floor($endOfDayH))
$endMinute = [int]([math]::Floor((($endOfDayH - $endHour) * 60)))
$endDt = Get-Date -Year $givenDate.Year -Month $givenDate.Month -Day $givenDate.Day -Hour $endHour -Minute $endMinute -Second 0

# --- Calculations ---
# Determine elapsed so far using times on the same reference day
# Normalize start and current to same date (use givenDate)
$startRef = Get-Date -Year $givenDate.Year -Month $givenDate.Month -Day $givenDate.Day -Hour $startDt.Hour -Minute $startDt.Minute -Second 0
$currentRef = Get-Date -Year $givenDate.Year -Month $givenDate.Month -Day $givenDate.Day -Hour $currentDt.Hour -Minute $currentDt.Minute -Second 0

# If current time is earlier than start, assume current is next day? For simplicity cap elapsed at 0
$currentHours = ToHours($currentRef)
$elapsedSoFar = [math]::Max(0.0, $currentHours - $startH)
$hoursRemainingToday = [math]::Max(0.0, $HoursPerWorkday - $elapsedSoFar)

# Monthly budget math
$allowedOverage = [math]::Max(0.0, $MonthlyBudget - $BasePlanPrice)
$allowedExtraRequests = [math]::Floor($allowedOverage / $OveragePricePerRequest)
$monthlyTargetRequests = $basePlanRequests + $allowedExtraRequests
$remainingMonthlyRequests = [math]::Max(0.0, $monthlyTargetRequests - $requestsMonth)

if ($daysLeftWorking -gt 0) {
    $projectedDailyNeeded = [math]::Ceiling($remainingMonthlyRequests / $daysLeftWorking)
} else {
    $projectedDailyNeeded = $remainingMonthlyRequests
}

# Today's remaining requests target = projectedDailyNeeded - requestsToday (not negative)
$todayRemainingRequests = [math]::Max(0.0, $projectedDailyNeeded - $requestsToday)
if ($hoursRemainingToday -gt 0) {
    $projectedHourlyNeededToday = [math]::Ceiling($todayRemainingRequests / $hoursRemainingToday)
} else {
    $projectedHourlyNeededToday = 0
}

# Current hourly rate = requestsMonth-to-date divided by total worked hours so far (completedWorkdays-1 full days + elapsedSoFar)
$workedFullDays = [math]::Max(0, $completedWorkdays - 1)
$workedHoursSoFar = ($workedFullDays * $HoursPerWorkday) + $elapsedSoFar
if ($workedHoursSoFar -le 0) { $currentHourlyRate = 0 } else { $currentHourlyRate = $requestsMonth / $workedHoursSoFar }

# projection from current month-average rate
$projectedMonthlyFromCurrentRate = $currentHourlyRate * $HoursPerWorkday * $workdaysInMonth

# --- Input mode menu: allow factoring today's run rate ---
# Modes:
# 1 = month-to-date only (default)
# 2 = provide month-to-date at start of day (compute requestsToday)
# 3 = provide today's start and current counts (compute requestsToday and today run-rate)
$projectedMonthlyFromTodayRate = $null
$todayHourlyRate = $null
$currentDailyFromRate_today = $null

Write-Host "" -ForegroundColor White
Write-Host "Select input mode for today's usage:" -ForegroundColor Cyan
Write-Host "  1) Month-to-date only (no today input)" -ForegroundColor White
Write-Host "  2) Provide month-to-date at start of day (script computes requestsToday)" -ForegroundColor White
Write-Host "  3) Provide today's start count and current count (script computes run-rate)" -ForegroundColor White
$mode = Read-Host "Enter 1, 2, or 3 (default 1)"
if ([string]::IsNullOrWhiteSpace($mode)) { $mode = '1' }

if ($mode -eq '1') {
    # leave $requestsToday as previously set (0.0)
} elseif ($mode -eq '2') {
    $monthStartInput = Read-Host "Month-to-date at start of day (number)"
    $monthStartVal = 0.0
    if (-not [double]::TryParse($monthStartInput, [ref]$monthStartVal)) { Write-Host "Invalid number for month-to-date at start of day." ; exit 1 }
    $requestsToday = [double]([math]::Max(0.0, $requestsMonth - $monthStartVal))
} elseif ($mode -eq '3') {
    # Use month-to-date as today's start (no need to ask again)
    $startVal = [double]$requestsMonth
    $todayCurrentInput = Read-Host "Today's current count (number)"
    $currentVal = 0.0
    if (-not [double]::TryParse($todayCurrentInput, [ref]$currentVal)) { Write-Host "Invalid number for today's current count." ; exit 1 }
    $requestsToday = [double]([math]::Max(0.0, $currentVal - $startVal))
    # compute today's run-rate if elapsed time > 0
    if ($elapsedSoFar -gt 0) {
        $todayHourlyRate = $requestsToday / $elapsedSoFar
        $currentDailyFromRate_today = $todayHourlyRate * $HoursPerWorkday
        $projectedMonthlyFromTodayRate = $todayHourlyRate * $HoursPerWorkday * $workdaysInMonth
    } else {
        $todayHourlyRate = 0
        $currentDailyFromRate_today = 0
        $projectedMonthlyFromTodayRate = 0
    }
} else {
    Write-Host "Invalid mode selection; defaulting to month-to-date only." -ForegroundColor Yellow
}

# --- Additional metrics ---
# Cost to date: base price plus overage if month-to-date exceeds base plan
if ($requestsMonth -le $basePlanRequests) {
    $costToDate = $BasePlanPrice
} else {
    $costToDate = $BasePlanPrice + (($requestsMonth - $basePlanRequests) * $OveragePricePerRequest)
}

# Remaining average requests needed per remaining working day
if ($daysLeftWorking -gt 0) {
    $remainingAvgPerWorkday = $remainingMonthlyRequests / $daysLeftWorking
} else {
    $remainingAvgPerWorkday = $remainingMonthlyRequests
}

# Current daily rate estimated from current hourly rate
$currentDailyFromRate = $currentHourlyRate * $HoursPerWorkday

# Projected cost if current rate continues for the month
if ($projectedMonthlyFromCurrentRate -le $basePlanRequests) {
    $projectedCostFromCurrentRate = $BasePlanPrice
} else {
    $projectedCostFromCurrentRate = $BasePlanPrice + (($projectedMonthlyFromCurrentRate - $basePlanRequests) * $OveragePricePerRequest)
}

# If we haven't computed a today's-based projection yet, but we do have requestsToday and elapsedSoFar,
# derive today's hourly rate and projection so we can display it in the summary.
if (($projectedMonthlyFromTodayRate -eq $null) -and ($requestsToday -gt 0) -and ($elapsedSoFar -gt 0)) {
    $todayHourlyRate = $requestsToday / $elapsedSoFar
    $currentDailyFromRate_today = $todayHourlyRate * $HoursPerWorkday
    $projectedMonthlyFromTodayRate = $todayHourlyRate * $HoursPerWorkday * $workdaysInMonth
}

# Projected cost if today's rate continues for the month (when available)
if ($projectedMonthlyFromTodayRate -ne $null) {
    if ($projectedMonthlyFromTodayRate -le $basePlanRequests) { $projectedCostFromTodayRate = $BasePlanPrice } else { $projectedCostFromTodayRate = $BasePlanPrice + (($projectedMonthlyFromTodayRate - $basePlanRequests) * $OveragePricePerRequest) }
} else { $projectedCostFromTodayRate = $null }

# --- Output (structured & colorized) ---
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "==== Forecast Summary ====" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

Write-Host "-- Input / Time --" -ForegroundColor DarkCyan
Write-Host ("Given date: {0:yyyy-MM-dd}" -f $givenDate) -ForegroundColor Yellow
Write-Host ("Start: {0:HH:mm}   Current: {1:HH:mm}   End-of-day: {2:HH:mm}" -f $startDt, $currentRef, $endDt) -ForegroundColor White
Write-Host ("Elapsed today (hrs): {0:N2}   Hours remaining today: {1:N2}" -f $elapsedSoFar, $hoursRemainingToday) -ForegroundColor White
Write-Host "" -ForegroundColor White

Write-Host "-- Usage --" -ForegroundColor DarkCyan
Write-Host ("Requests month-to-date: {0:N2}" -f $requestsMonth) -ForegroundColor Green
Write-Host ("Requests today (computed): {0:N2}" -f $requestsToday) -ForegroundColor Green
Write-Host "" -ForegroundColor White

Write-Host "-- Workdays / Holidays --" -ForegroundColor DarkCyan
Write-Host ("Day of month: {0}   Workdays this month: {1}   Completed: {2}   Left: {3}" -f $dayOfMonth, $workdaysInMonth, $completedWorkdays, $daysLeftWorking) -ForegroundColor Yellow
Write-Host ("US federal holidays this month: {0}" -f (($holThisMonth | ForEach-Object { ([datetime]$_).ToString('yyyy-MM-dd') }) -join ', ')) -ForegroundColor DarkCyan
Write-Host "" -ForegroundColor White

Write-Host "-- Budget / Plan --" -ForegroundColor DarkCyan
Write-Host ('Base plan requests: {0}   Base plan price: ${1:N2}' -f $basePlanRequests, $BasePlanPrice) -ForegroundColor Green
Write-Host ('Overage price/request: ${0:N2}   Monthly budget cap: ${1:N2}' -f $OveragePricePerRequest, $MonthlyBudget) -ForegroundColor Green
Write-Host ('Allowed extra requests under budget: {0}' -f $allowedExtraRequests) -ForegroundColor Yellow
Write-Host ('Monthly target requests to stay ≤ budget: {0}' -f $monthlyTargetRequests) -ForegroundColor Yellow
Write-Host ('Remaining monthly requests available: {0:N2}' -f $remainingMonthlyRequests) -ForegroundColor Green
Write-Host ('Cost to date: ${0:N2}' -f $costToDate) -ForegroundColor Green
$projCurColor = 'Yellow'
if ($projectedCostFromCurrentRate -gt $MonthlyBudget) { $projCurColor = 'Red' }
Write-Host ('Projected monthly cost (from month-average rate): ${0:N2}' -f $projectedCostFromCurrentRate) -ForegroundColor $projCurColor
Write-Host "" -ForegroundColor White

if ($projectedMonthlyFromTodayRate -ne $null) {
    Write-Host "-- Today's Run Projection --" -ForegroundColor DarkCyan
    Write-Host ("Requests so far today: {0:N2}   Hourly rate (req/hr): {1:N2}" -f $requestsToday, $todayHourlyRate) -ForegroundColor White
    Write-Host ("Projected monthly requests if today's rate continues: {0:N0}" -f $projectedMonthlyFromTodayRate) -ForegroundColor Yellow
    $projTodayColor = 'Yellow'
    if ($projectedCostFromTodayRate -gt $MonthlyBudget) { $projTodayColor = 'Red' }
    Write-Host ('Projected monthly cost if today''s rate continues: ${0:N2}' -f $projectedCostFromTodayRate) -ForegroundColor $projTodayColor
    Write-Host "" -ForegroundColor White
}

Write-Host "-- Projections & Targets --" -ForegroundColor DarkCyan
Write-Host ('Projected monthly requests if current rate continues: {0:N0}' -f $projectedMonthlyFromCurrentRate) -ForegroundColor Yellow
Write-Host ('Projected daily requests needed (remaining workdays): {0}' -f $projectedDailyNeeded) -ForegroundColor Yellow
Write-Host ('Today''s remaining requests to hit daily target: {0:N2}' -f $todayRemainingRequests) -ForegroundColor Yellow
Write-Host ('Projected hourly requests needed for rest of today: {0}' -f $projectedHourlyNeededToday) -ForegroundColor Yellow
Write-Host "" -ForegroundColor White

# Comparisons / Alerts
$cmpCount = 0
Write-Host "-- Comparisons & Alerts --" -ForegroundColor DarkMagenta
if ($projectedMonthlyFromTodayRate -ne $null) {
    $diff = $projectedMonthlyFromTodayRate - $monthlyTargetRequests
    if ($diff -gt 0) { Write-Host ("ALERT: Today's-rate projection exceeds monthly target by {0:N0} requests" -f $diff) -ForegroundColor Red; $cmpCount++ } else { Write-Host ("OK: Today's-rate projection is {0:N0} requests below monthly target" -f ([math]::Abs($diff))) -ForegroundColor Green }
}

$diffCurrent = $projectedMonthlyFromCurrentRate - $monthlyTargetRequests
if ($diffCurrent -gt 0) { Write-Host ("WARN: Current-rate projection exceeds monthly target by {0:N0} requests" -f $diffCurrent) -ForegroundColor Yellow; $cmpCount++ } else { Write-Host ("OK: Current-rate projection is {0:N0} requests below monthly target" -f ([math]::Abs($diffCurrent))) -ForegroundColor Green }

if ($projectedCostFromTodayRate -ne $null) {
    $costDiff = $projectedCostFromTodayRate - $MonthlyBudget
    if ($costDiff -gt 0) { Write-Host ("ALERT: Projected monthly cost (today's rate) exceeds budget by {0:N2}" -f $costDiff) -ForegroundColor Red; $cmpCount++ } else { Write-Host ("OK: Projected monthly cost (today's rate) is {0:N2} below budget" -f ([math]::Abs($costDiff))) -ForegroundColor Green }
}

$costDiffCur = $projectedCostFromCurrentRate - $MonthlyBudget
if ($costDiffCur -gt 0) { Write-Host ("WARN: Projected monthly cost (current rate) exceeds budget by {0:N2}" -f $costDiffCur) -ForegroundColor Yellow; $cmpCount++ } else { Write-Host ("OK: Projected monthly cost (current rate) is {0:N2} below budget" -f ([math]::Abs($costDiffCur))) -ForegroundColor Green }

if ($cmpCount -eq 0) { Write-Host "No alerts - projections are within targets/budget." -ForegroundColor Cyan }

# Explanation: why Today's and Current projections can differ
Write-Host "" -ForegroundColor White
Write-Host "-- Why Today's vs Current may differ --" -ForegroundColor DarkMagenta
Write-Host "Today's rate is a short-term run-rate (requests today / elapsed hours)." -ForegroundColor White
Write-Host "Current rate is the month-to-date average (total requestsMonth / hours worked so far)." -ForegroundColor White
Write-Host "Consequences:" -ForegroundColor Yellow
Write-Host " - A high burst today can make Today's projection (extrapolating this day's rate) exceed the monthly target even if the historical Current rate remains below it." -ForegroundColor Yellow
Write-Host " - The Recommendation (Allowed) is computed from remaining requests divided by remaining hours — it's the average rate you must hold from now on to hit the monthly target." -ForegroundColor Yellow
Write-Host " - Use Today's rate for immediate throttling decisions; use Current rate to understand the overall trend." -ForegroundColor Yellow

# Recommendation: compute allowed average hourly rate for remaining work hours to stay within monthly target
$remainingWorkingHours = ($daysLeftWorking * $HoursPerWorkday) + $hoursRemainingToday
if ($remainingWorkingHours -le 0) { $allowedHourlyRateForRemaining = 0 } else { $allowedHourlyRateForRemaining = $remainingMonthlyRequests / $remainingWorkingHours }
$allowedDailyEquivalent = $allowedHourlyRateForRemaining * $HoursPerWorkday

# Show recommendation and color it red if current hourly rate or today's hourly rate exceed allowable
$recColor = 'Green'
if ($currentHourlyRate -gt $allowedHourlyRateForRemaining) { $recColor = 'Red' }
if ($todayHourlyRate -ne $null -and $todayHourlyRate -gt $allowedHourlyRateForRemaining) { $recColor = 'Red' }
Write-Host ("Recommendation: To stay within monthly target, average ≤ {0:N2} req/hr for remaining work hours (~ {1:N2} req/day)" -f $allowedHourlyRateForRemaining, $allowedDailyEquivalent) -ForegroundColor $recColor

# Per-hour throttle recommendation for the remainder of today
if ($hoursRemainingToday -gt 0) {
    $allowedHourlyToday = $remainingMonthlyRequests / $hoursRemainingToday
    # Keep a conservative suggestion: min of allowedHourlyRateForRemaining and allowedHourlyToday
    $throttleRec = [math]::Min($allowedHourlyRateForRemaining, $allowedHourlyToday)
    $throttleColor = 'Green'
    if ($todayHourlyRate -ne $null -and $throttleRec -lt $todayHourlyRate) { $throttleColor = 'Red' }
    # If the throttle recommendation is effectively the same as the overall allowed hourly rate, skip duplicate line
    if ([math]::Abs($throttleRec - $allowedHourlyRateForRemaining) -ge 0.01) {
        Write-Host ("Throttle recommendation (remainder of today): limit to ≤ {0:N2} req/hr" -f $throttleRec) -ForegroundColor $throttleColor
    }
}

# Simple ASCII bar graph comparing allowed vs current vs today's hourly rates
if ($todayHourlyRate -ne $null) { $todayRateVal = $todayHourlyRate } else { $todayRateVal = 0.0 }
# Nested Max (PowerShell/.NET Math.Max supports two args only) and guard against non-finite values
$graphMax = [math]::Max([math]::Max([math]::Max($allowedHourlyRateForRemaining, $currentHourlyRate), $todayRateVal), 1.0)
if ([double]::IsInfinity($graphMax) -or [double]::IsNaN($graphMax) -or $graphMax -le 0) { $graphMax = 1.0 }

function Get-Bar([double]$val, [double]$max) {
    $width = 40
    if ([double]::IsInfinity($val) -or [double]::IsNaN($val)) { $val = 0.0 }
    if ([double]::IsInfinity($max) -or [double]::IsNaN($max) -or $max -le 0) { $max = 1.0 }
    $ratio = $val / $max
    if ([double]::IsInfinity($ratio) -or [double]::IsNaN($ratio)) { $ratio = 0.0 }
    $len = [int]([math]::Round($ratio * $width))
    if ($len -lt 0) { $len = 0 }
    if ($len -gt $width) { $len = $width }
    return ('=' * $len) + (' ' * ($width - $len))
}
Write-Host "" -ForegroundColor White
Write-Host "-- Rate Comparison (req/hr) --" -ForegroundColor DarkCyan
Write-Host "Legend:" -ForegroundColor DarkCyan
Write-Host "  - Allowed : avg req/hr you can sustain for all remaining work hours (green)" -ForegroundColor Green
Write-Host "  - Current : month-to-date average req/hr so far (yellow)" -ForegroundColor Yellow
Write-Host "  - Today's  : current day's run-rate (req/hr) - noisy early; turns red if above Allowed" -ForegroundColor Cyan
$allowedLine = ('Allowed  : [{0}] {1:N2} req/hr' -f (Get-Bar $allowedHourlyRateForRemaining $graphMax), $allowedHourlyRateForRemaining)
Write-Host $allowedLine -ForegroundColor Green
$currentLine = ('Current  : [{0}] {1:N2} req/hr' -f (Get-Bar $currentHourlyRate $graphMax), $currentHourlyRate)
Write-Host $currentLine -ForegroundColor Yellow
if ($todayHourlyRate -ne $null) {
    $todayColor = 'Cyan'
    # Use a small tolerance to avoid floating-point rounding hiding slight overruns
    if ($todayHourlyRate -gt ($allowedHourlyRateForRemaining + 0.0001)) { $todayColor = 'Red' }
    $todayLine = ('Today    : [{0}] {1:N2} req/hr' -f (Get-Bar $todayHourlyRate $graphMax), $todayHourlyRate)
    Write-Host $todayLine -ForegroundColor $todayColor
}
Write-Host "====================================" -ForegroundColor Cyan

