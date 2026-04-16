function cir = helperChannelImpulseResponse(cfr,Nfft,Ncp,activeFFTInd,varargin)
%channelImpulseResponse Reconstruct channel impulse response from channel frequency response
%   CIR = helperChannelImpulseResponse(CFR,NFFT,NCP,ACTIVEFFTIND)
%   reconstructs the channel impulse response from the channel frequency
%   response. The CIR is reconstructed by linearly interpolated across
%   inactive subcarriers and the guard band, then taking the IFFT.
%
%   CIR is a NFFT-by-Nsts-by-Nr array containing the channel
%   impulse responses. NFFT is the FFT length, Nsts is the number of
%   space-time-streams, and Nr is the number of receive antennas.
%
%   CFR is a NST-by-Nsts-by-Nr array containing the channel frequency
%   response. NST is the number of active subcarriers. The active
%   subcarrier indices making up NST is given by the ACTIVEFFTIND argument.
%
%   NFFT is the FFT length.
%
%   NCP is the cyclic prefix length.
%
%   ACTIVEFFTIND is a vector of active subcarrier indices within the FFT
%   (range 1:NFFT).

%   Copyright 2020-2023 The MathWorks, Inc.

if nargin>4
    symOffset = varargin{1};
else
    symOffset = 1; % Default symbol offset for OFDM demodulation
end

[~,Nsts,Nr] = size(cfr);         

y = coder.nullcopy(zeros(Nfft,Nsts,Nr,'like',cfr));

% Linear interpolation over DC and nulls
magPart = interp1(activeFFTInd,abs(cfr),activeFFTInd(1):activeFFTInd(end));
phasePart = interp1(activeFFTInd,unwrap(angle(cfr),[],1),activeFFTInd(1):activeFFTInd(end));
[realPart,imagPart] = pol2cart(phasePart,magPart);
y(activeFFTInd(1):activeFFTInd(end),:,:) = complex(realPart,imagPart);

% Linear interpolation across guard band (assuming cyclic)
magPart = interp1([activeFFTInd(end)-activeFFTInd(1) Nfft],abs(cfr([end; 1],:,:)),(activeFFTInd(end)-activeFFTInd(1)+1):(Nfft-1));
phasePart = interp1([activeFFTInd(end)-activeFFTInd(1) Nfft],unwrap(angle(cfr([end; 1],:,:)),[],1),(activeFFTInd(end)-activeFFTInd(1)+1):(Nfft-1));
[realPart,imagPart] = pol2cart(phasePart,magPart);    
y([((activeFFTInd(end)+1):Nfft) (1:activeFFTInd-1)],:,:) = complex(realPart,imagPart);

% Obtain the time domain channel impulse responses
imp = ifft(ifftshift(y,1),[],1);
offset = floor((1-symOffset)*Ncp);
cir = circshift(imp,offset,1);