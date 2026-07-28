unit productiongate;

// One fail-closed admission call for GUI, CLI, and future service front ends.
//
// Successful admission returns the authenticated job plus the exact verified
// image stream, still open with write/delete sharing denied.  The caller owns
// that stream and must program from it rather than reopen the path.

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, prodjob, electricalpreflight;

type
  TProductionAdmissionFailure = (
    pafNone,
    pafJobAuthentication,
    pafChipDefinitionIntegrity,
    pafImageIntegrity,
    pafElectricalPreflight
  );

// Key and ChipDefinitionBytes are borrowed for this call and are not retained.
// VerificationUTC must come from the station's trusted UTC source.
//
// On success:
//   - Job is authenticated and within its validity window;
//   - the chip definition and image match their mandatory SHA-256 values;
//   - ElectricalReport.Allowed is true under the strict production policy;
//   - ImageStream is positioned at zero and owned by the caller.
//
// On any failure ImageStream is nil and Failure identifies the rejected gate.
function AdmitHMACProductionJob(const ManifestFile, AuthFile,
  ExpectedKeyID: string; const Key: TBytes; VerificationUTC: QWord;
  const ChipDefinitionBytes: TBytes;
  const Programmer: TProgrammerElectricalCapabilities;
  const Adapter: TAdapterElectricalCapabilities;
  const Observation: TElectricalObservation;
  out Job: TProductionJob; out ImageStream: TFileStream;
  out ElectricalReport: TPreflightReport;
  out Failure: TProductionAdmissionFailure;
  out ErrMsg: string): boolean;

function ProductionAdmissionFailureName(
  Failure: TProductionAdmissionFailure): string;

implementation

function FirstElectricalError(const Report: TPreflightReport): string;
begin
  if Length(Report.Issues) = 0 then
    Exit('electrical preflight rejected the operation without an issue');
  Result := PreflightIssueCodeName(Report.Issues[0].Code) + ': ' +
            Report.Issues[0].Detail;
  if Length(Report.Issues) > 1 then
    Result := Result + Format(' (and %d more issue(s))',
                              [Length(Report.Issues) - 1]);
end;

function AdmitHMACProductionJob(const ManifestFile, AuthFile,
  ExpectedKeyID: string; const Key: TBytes; VerificationUTC: QWord;
  const ChipDefinitionBytes: TBytes;
  const Programmer: TProgrammerElectricalCapabilities;
  const Adapter: TAdapterElectricalCapabilities;
  const Observation: TElectricalObservation;
  out Job: TProductionJob; out ImageStream: TFileStream;
  out ElectricalReport: TPreflightReport;
  out Failure: TProductionAdmissionFailure;
  out ErrMsg: string): boolean;
var
  ManifestDirectory, ResolvedImage: string;
  Requirements: TTargetElectricalRequirements;
  Policy: TPreflightPolicy;
  CandidateJob: TProductionJob;
begin
  Result := False;
  ClearProductionJob(Job);
  ImageStream := nil;
  ElectricalReport.Allowed := False;
  ElectricalReport.MaxSafeBusHz := 0;
  SetLength(ElectricalReport.Issues, 0);
  Failure := pafJobAuthentication;
  ErrMsg := '';

  if not LoadAuthenticatedProductionJob(ManifestFile, AuthFile,
    ExpectedKeyID, Key, VerificationUTC, CandidateJob, ErrMsg) then Exit;

  Failure := pafChipDefinitionIntegrity;
  if not VerifyChipDefinitionBytes(CandidateJob, ChipDefinitionBytes,
                                   ErrMsg) then Exit;

  Failure := pafImageIntegrity;
  ManifestDirectory := ExtractFileDir(ExpandFileName(ManifestFile));
  if not OpenVerifiedProductionImage(CandidateJob, ManifestDirectory,
    ImageStream, ResolvedImage, ErrMsg) then Exit;

  Requirements := JobToElectricalRequirements(CandidateJob);
  DefaultProductionPreflightPolicy(Policy);
  ElectricalReport := EvaluateElectricalPreflight(
    Programmer, Adapter, Requirements, Observation, Policy);
  if not ElectricalReport.Allowed then
  begin
    Failure := pafElectricalPreflight;
    ErrMsg := FirstElectricalError(ElectricalReport);
    FreeAndNil(ImageStream);
    Exit;
  end;

  Failure := pafNone;
  Job := CandidateJob;
  Result := True;
end;

function ProductionAdmissionFailureName(
  Failure: TProductionAdmissionFailure): string;
begin
  case Failure of
    pafNone: Result := 'none';
    pafJobAuthentication: Result := 'job_authentication';
    pafChipDefinitionIntegrity: Result := 'chip_definition_integrity';
    pafImageIntegrity: Result := 'image_integrity';
    pafElectricalPreflight: Result := 'electrical_preflight';
  end;
end;

end.
