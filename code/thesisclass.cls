%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Important: Do not change anything in this file!%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\NeedsTeXFormat{LaTeX2e} % We do need LaTeX2e
\ProvidesClass{thesisclass}
\LoadClass[
    fontsize=12pt,
    oneside,
    openany,
    abstract=true,
]{scrreprt}	% Class based on scrbook
%  Style: Add openany to avoid blank pages after every chapter


\usepackage[ngerman,USenglish]{babel}
\usepackage[ngerman,USenglish]{isodate}
\daymonthsepgerman{}%
\monthyearsepgerman{}{}%

%% -------------------------------
%% |      Define commands        |
%% -------------------------------

\newcommand*{\@germantitle}{}
\newcommand*{\germantitle}[1]{\renewcommand\@germantitle{#1}}
\newcommand*{\@firstexaminer}{}
\newcommand*{\firstexaminer}[1]{\renewcommand\@firstexaminer{#1}}
\newcommand*{\@secondexaminer}{}
\newcommand*{\secondexaminer}[1]{\renewcommand\@secondexaminer{#1}}
\newcommand*{\@firstsupervisor}{}
\newcommand*{\firstsupervisor}[1]{\renewcommand\@firstsupervisor{#1}}
\newcommand*{\@secondsupervisor}{}
\newcommand*{\secondsupervisor}[1]{\renewcommand\@secondsupervisor{#1}}
\newcommand*{\@thirdsupervisor}{}
\newcommand*{\thirdsupervisor}[1]{\renewcommand\@thirdsupervisor{#1}}
\newcommand*{\@degree}{}
\newcommand*{\degree}[1]{\renewcommand\@degree{#1}}
\newcommand*{\@studiengang}{}
\newcommand*{\studiengang}[1]{\renewcommand\@studiengang{#1}}
\newcommand*{\@matricle}{}
\newcommand*{\matricle}[1]{\renewcommand\@matricle{#1}}
\newcommand*{\@startdate}{}
\newcommand*{\startdate}[1]{\renewcommand\@startdate{#1}}
\newcommand*{\@submissiondate}{}
\newcommand*{\submissiondate}[1]{\renewcommand\@submissiondate{#1}}
\newcommand*{\@type}{}
\newcommand*{\type}[1]{%
    \ifthenelse{\equal{#1}{Bachelor}}%
        {\renewcommand\@type{\iflanguage{english}{Bachelor's thesis}{Bachelorarbeit}}}{}
    \ifthenelse{\equal{#1}{Master}}%
        {\renewcommand\@type{\iflanguage{english}{Master's Thesis}{Masterarbeit}}}{}
    \ifthenelse{\equal{#1}{Seminar}}%
        {\renewcommand\@type{\iflanguage{english}{Seminar thesis}{Seminararbeit}}}{}%
    \ifthenelse{\equal{#1}{Project}}%
        {\renewcommand\@type{\iflanguage{english}{Research project}{Studienarbeit}}}{}%
}
\newcommand*{\@Author}{\@author}

\newcommand{\thesisnotice}[1]{%
  \iflanguage{english}{%
    \ifthenelse{\equal{#1}{Bachelor's thesis} \or \equal{#1}{Master's thesis}}%
      {A summary of the thesis in form of a poster or a video must be submitted before the defense. }%
      {}%
  }{%
    \ifthenelse{\equal{#1}{Bachelorarbeit} \or \equal{#1}{Masterarbeit}}%
      {Eine Zusammenfassung der Arbeit in Form eines Posters oder eines Videos muss bis zur Verteidigung vorliegen. }%
      {}%
  }%
}



\renewcommand{\maketitle}{
    \begin{titlepage}
	
	\begin{textblock}{10}[1,0](24,2.5)
		\includesvg[width=.25\textwidth]{logos/tuhh_logo.svg}
	\end{textblock}
    \begin{textblock}{6}[1,0](18.3,2.5)
		\includesvg[width=.25\textwidth]{logos/IDAC_Logo.svg}
	\end{textblock}
	\begin{textblock}{10}[0,0](4,2.5)
    \begin{spacing}{0.85}
    \textcolor{idac_blue}{\small{\iflanguage{english}{\textbf{Institute of}\\
            \textbf{Digital and Autonomous Construction}\\
            Professor Dr. Kay Smarsly
        }{\textbf{Institut für}\\
            \textbf{Digitales und Autonomes Bauen}\\
            Prof. Dr.-Ing. Kay Smarsly
        }
    }}
    \end{spacing}
\end{textblock}

	% \changefont{ppl}{m}{n}
	\vspace*{3cm}
	\begin{center}
		\LARGE{\scshape \@type}
		% \vspace*{2cm}\\ % reduce vspace if title page spreads over two pages
        %\vspace{\fill}

        \normalsize{\iflanguage{english}{for the degree program of \@degree}{im Studiengang \@studiengang}}
        
		\vspace{\fill}

        \LARGE{\textbf{\iflanguage{english}{\@title}{\@germantitle}}}

        \normalsize{\textit{\iflanguage{english}{\@germantitle}{\@title}}}
        
		\vspace*{2.5cm}
		\normalsize{\@Author}\\
		\normalsize{\iflanguage{english}{Matriculation number:}{Matrikelnummer:} \@matricle}\\
		\normalsize{\printdate{\@date}}
	\end{center}
	\vspace*{\fill} % reduce vspace if title page spreads over two pages
	\normalsize{
		%\begin{center}
			\begin{tabular}[ht]{@{}p{4cm} l@{}}
				\textbf{\iflanguage{english}{First examiner}{Erstpr\"ufer}:}  & \@firstexaminer \\
				\textbf{\iflanguage{english}{Second examiner}{Zweitpr\"ufer}:}  & \@secondexaminer \\
                \textbf{Supervisors:}  & \@firstsupervisor  \\  & 
                \@secondsupervisor \\  &
                \@thirdsupervisor \\
			
			\end{tabular}
		%\end{center}
	}
	
	\vspace{\fill} % reduce vspace if title page spreads over two pages
	
\end{titlepage}
}

\newcommand{\printtaskdescription}{

    \input{XXTastDescriptionContent}

	\begin{textblock}{10}[1,0](24,2.5)
		\includesvg[width=.25\textwidth]{logos/tuhh_logo.svg}
	\end{textblock}
    \begin{textblock}{6}[1,0](18.3,2.5)
		\includesvg[width=.25\textwidth]{logos/IDAC_Logo.svg}
	\end{textblock}
	\begin{textblock}{10}[0,0](4,2.5)
    \begin{spacing}{0.85}
    \textcolor{idac_blue}{\small{\iflanguage{english}{\textbf{Institute of}\\
            \textbf{Digital and Autonomous Construction}\\
            Professor Dr. Kay Smarsly
        }{\textbf{Institut für}\\
            \textbf{Digitales und Autonomes Bauen}\\
            Prof. Dr.-Ing. Kay Smarsly
        }
    }}
    \end{spacing}
\end{textblock}

	% \changefont{ppl}{m}{n}
	\vspace*{2cm}

		\large{\textbf{\@type { for} \@Author}}
		% \vspace*{2cm}\\ % reduce vspace if title page spreads over two pages
        %\vspace{\fill}

        \noindent
        \begin{tabular}[ht]{ll}
        \normalsize{\iflanguage{english}{Degree program:}{Studiengang:}}
        & \normalsize{\iflanguage{english}{\@degree}{\@studiengang}}\\
        \normalsize{\iflanguage{english}{Matriculation number:}{Matrikelnummer:}}
        & \normalsize{\@matricle}
        \end{tabular}

        \vspace*{1cm}

        \textbf{\iflanguage{english}{Topic}{Thema}}
        
        \normalsize{\iflanguage{english}{\@title}{\@germantitle}}\\
        \normalsize{\textit{\iflanguage{english}{\@germantitle}{\@title}}}

        \vspace*{0.5cm}
        \large{\textbf{\iflanguage{english}{Introduction}{Einf\"uhrung}}}

        \normalsize{\taskintro}

        
        \vspace*{0.5cm}
        \large{\textbf{\iflanguage{english}{Tasks}{Aufgaben}}}

        \normalsize
        \tasklist
        
		\vspace*{0.5cm}
		\iflanguage{english}{
        \textit{Assembling the written documentation, also referred to as “the thesis” or “the paper”, will start at the same time when the master thesis period starts, and it will begin with iteratively defining a proper structure together with the supervisor. To ensure transparency and support an open communication during supervision, the documentation will be written in parallel to conducting the tasks defined above; the student will receive further support by discussing the current status of the documentation with the supervisor in regular intervals (at least once a month). Therefore, the current status of the documentation will be submitted to the supervisor at the end of each month (and more frequently when required). To ensure that the thesis can be assessed within the required deadlines, the defense date must be arranged no later than the midpoint of the thesis work period, but can also be set right at the start of the thesis work, which is solely the responsibility of the student. The thesis must be submitted both digitally (PDF) and as hardcopy (2 copies). \thesisnotice{\@type}The source files of the thesis (Word or LaTeX), the source files of embedded figures and of other related files (sensor data, source codes, etc.) and other sources that are not freely available must be submitted together with the thesis.}
        }{
        \textit{Die Erstellung der schriftlichen Dokumentation, umgangssprachlich auch als „die Arbeit“ oder „das Paper“ bezeichnet, beginnt zeitgleich mit dem Beginn des Bearbeitungszeitraums und startet mit der iterativen Definition einer geeigneten Struktur, was gemeinsam mit dem/der Betreuer/in erfolgt. Um Transparenz und eine offene Kommunikation während der Bearbeitung zu gewährleisten, wird die Dokumentation parallel zu den oben definierten Aufgaben geschrieben; weitere Unterstützung erhält der/die Student/in, indem er/sie in regelmäßigen Abständen (mindestens einmal im Monat) den aktuellen Stand der Dokumentation und den Stand der Bearbeitung mit dem/der Betreuer/in bespricht. Hierzu sendet er/sie den aktuellen Stand der Dokumentation am Ende eines jeden Monats an den/die Betreuer/in (und bei Bedarf dementsprechend häufiger). Um sicherzustellen, dass die Arbeit innerhalb der vorgegebenen Fristen bewertet werden kann, muss der Verteidigungstermin spätestens zur Mitte der Bearbeitungszeit festgelegt werden, kann aber auch direkt zu Beginn der Bearbeitung angesetzt werden, was in der alleinigen Verantwortung des/der Student/in liegt. Die Arbeit muss sowohl digital (PDF) als auch in Papierform (2 Exemplare) eingereicht werden. \thesisnotice{\@type}Die Quelldateien der Arbeit (Word oder LaTeX), die Quelldateien von eingebetteten Abbildungen und andere verwandte Dateien (Datenschemata, Quellcode, etc.) müssen genauso zusammen mit der Arbeit digital eingereicht werden, wie nicht frei zugängliche Quellen.}
}

		

	\vspace*{0.5cm}
    
	\normalsize{
		%\begin{center}
			\begin{tabular}[ht]{@{}p{4cm} l@{}}
                \textbf{\iflanguage{english}{Start:}{Ausgabe:}}  & \@startdate \\
                \textbf{\iflanguage{english}{Submission:}{Abgabe:}}  & \@submissiondate \\
				\textbf{\iflanguage{english}{First examiner}{Erstpr\"ufer}:}  & \@firstexaminer \\
				\textbf{\iflanguage{english}{Second examiner}{Zweitpr\"ufer}:}  & \@secondexaminer \\
                \textbf{Supervisors:}  & \@firstsupervisor  \\  & 
                \@secondsupervisor \\  &
                \@thirdsupervisor \\
			
			\end{tabular}
		%\end{center}
	}

	\vspace{\fill} % reduce vspace if title page spreads over two pages
}

\newcommand{\printdeclaration}{
    \iflanguage{english}{

        \begin{selectlanguage}{ngerman}
        \section*{Eidesstattliche Erklärung}
    
        Ich, \textit{\@Author}, erkläre hiermit an Eides statt, dass ich die vorliegende Arbeit \textit{\@title} selbstständig verfasst sowie keine anderen als die vollständig angegebenen Quellen und Hilfsmittel benutzt habe und dass die Arbeit nicht bereits als Prüfungsarbeit vorgelegen hat.
        
        \end{selectlanguage}
        
        \section*{Statutory Declaration}

        I, \textit{\@Author}, hereby declare that this thesis \textit{\@title} has been written only by the undersigned and without any assistance from third parties. Furthermore, I confirm that no sources have been used in the preparation of this thesis other than those specified in the thesis itself. This thesis, in same or similar form, has not been available to any audit authority yet.

        \vspace*{1cm}

        \noindent
        \makebox[0.45\textwidth]{\hrulefill} \hfill
        \makebox[0.45\textwidth]{\hrulefill} \\
        \makebox[0.45\textwidth]{Location, Date} \hfill
        \makebox[0.45\textwidth]{Signature}

    }{

    \begin{selectlanguage}{ngerman}
    \section*{Eidesstattliche Erklärung}

    Ich, \textit{\@Author}, erkläre hiermit an Eides statt, dass ich die vorliegende Arbeit \textit{\@title} selbstständig verfasst sowie keine anderen als die vollständig angegebenen Quellen und Hilfsmittel benutzt habe und dass die Arbeit nicht bereits als Prüfungsarbeit vorgelegen hat.
    
    \vspace*{1cm}

    \noindent
    \makebox[0.45\textwidth]{\hrulefill} \hfill
    \makebox[0.45\textwidth]{\hrulefill} \\
    \makebox[0.45\textwidth]{Ort, Datum} \hfill
    \makebox[0.45\textwidth]{Unterschrift}

    \pagenumbering{gobble}
    \end{selectlanguage}}

    \newpage
}


\counterwithout{footnote}{chapter}
\counterwithout{equation}{chapter}
\counterwithout{table}{chapter}
\counterwithout{figure}{chapter}

% \patchcmd{\chapter}{\if@openright\cleardoublepage\else\clearpage\fi}{}{}{}
% \patchcmd{\scr@startchapter}{\if@openright\cleardoublepage\else\clearpage\fi}{}{}{}

%% -------------------------------
%% |          Packages           |
%% -------------------------------

\usepackage[T1]{fontenc}
\usepackage[utf8]{inputenc}
\usepackage[pdftex]{graphicx}
\usepackage{vmargin}          % Adjust margins in a simple way
\usepackage{subfigure}
\usepackage{url}
\usepackage[absolute,overlay]{textpos}
\usepackage{tikz}
\usepackage{etoolbox}
					
%%  Packages
\usepackage{setspace} % 1.5 line spacing
\onehalfspacing

\usepackage[
    raiselinks=true,
    bookmarks=true,
    bookmarksopenlevel=1,
    bookmarksopen=true,
    bookmarksnumbered=true,
    hyperindex=true,
    plainpages=false,
    pdfpagelabels=true,
    pdfborder={0 0 0.5},
    colorlinks=false,
    pdfusetitle=true,
    linkbordercolor={0 0.61 0.50},   
    citebordercolor={0 0.61 0.50}
]{hyperref}  %{0.57 0.74 0.57}
\AtBeginDocument{
    \hypersetup{
        pdfsubject={\@type}
    }
}

%% --- End of Packages ---



%% -------------------------------
%% |        Declarations         |
%% -------------------------------
\DeclareGraphicsExtensions{.svg}
%% --- End of Declarations ---



%% -------------------------------
%% |         New commands        |
%% -------------------------------
\newcommand{\changefont}[3]{\fontfamily{#1} \fontseries{#2} \fontshape{#3} \selectfont}
%\renewcommand*{\headfont}{\slshape}
%\newcommand{\captionfont}{}
\newcommand{\chapterheadfont}{}
\newcommand{\blankpage}{
 \clearpage{\pagestyle{empty}\cleardoublepage}
}
%% --- End of New Commands ---



%% -------------------------------
%% |      Globale Settings       |
%% -------------------------------
\setcounter{secnumdepth}{3} % Numbering also for \subsubsections
\setcounter{tocdepth}{3}    % Register \subsubsections in content directory

\setpapersize{A4}
\setmarginsrb{3cm}{1cm}{3cm}{1cm}{6mm}{7mm}{5mm}{15mm}

\parindent 0cm                     % Do not indent beginning of paragraph
\parskip1.5ex plus0.5ex minus0.5ex % Margin between paragraphs
%% --- End of global Settings ---



%% -------------------------------
%% |          Headings           |
%% -------------------------------
\pagestyle{plain}
%\pagestyle{fancy}
%\renewcommand{\chaptermark}[1]{\markboth{\thechapter.\ #1}{}}
%\fancyhf{}
%\fancyhead[LE,RO]{{\headfont\thepage}}						% Left/right header for even/odd pages
%\fancyhead[LO]{\headfont\nouppercase{\rightmark}}	% Header for left page (odd)
%\fancyhead[RE]{\headfont\nouppercase{\leftmark}}	% Header for right page (even)
%\fancyfoot[C]{\thepage}
%\renewcommand{\headrulewidth}{0.5pt}
%\renewcommand{\footrulewidth}{0pt}
%\fancypagestyle{plain}{%
%\fancyhf{}													% No Header and Footer fields
%\renewcommand{\headrulewidth}{0pt}
%\renewcommand{\footrulewidth}{0pt}
%\fancyfoot[C]{\thepage}
%}
%% --- End of Headings ---



%% -------------------------------
%% |      Style of captions      |
%% -------------------------------


\renewcommand{\chapter}{%
	\scr@startsection{chapter}%
	{0}		% Structure level
	{0mm}	% Indention
	{2ex plus 1ex minus 1ex}			% Pre-Margin
	{0.5ex plus 0.5ex minus 0.5ex}		% Post-Margin
	{\chapterheadfont\huge}	% Style
}

\renewcommand{\section}{%
\scr@startsection{section}%
{1}		% Structure level
{0mm}	% Indention
{2ex plus 1ex minus 1ex}			% Pre-Margin
{0.5ex plus 0.5ex minus 0.5ex}		% Post-Margin
{\chapterheadfont\Large}	% Style
}
\renewcommand{\subsection}{%
\scr@startsection{subsection}%
{2}		% Structure level
{0mm}	% Indention
{1.5ex plus 1ex minus 0.5ex}		% Pre-Margin
{0.3ex plus 0.3ex minus 0.3ex}		% Post-Margin
{\chapterheadfont\large}	% Style
}
\renewcommand{\subsubsection}{%
\scr@startsection{subsubsection}%
{3}		% Structure level
{0mm}	% Indention
{1.5ex plus 1ex minus 0.5ex}			% Pre-Margin
{0.2ex plus 0.2ex minus 0.2ex}			% Post-Margin
{\chapterheadfont\normalsize}	% Style
}
\renewcommand{\paragraph}{%
\scr@startsection{paragraph}%
{4}		% Structure level
{0mm}	% Indention
{1.3ex plus 1ex minus 0.3ex}			% Pre-Margin
{0.2ex plus 0.2ex minus 0.2ex}			% Post-Margin
{\chapterheadfont\normalsize}	% Style
}
\renewcommand{\subparagraph}{%
\scr@startsection{subparagraph}%
{5}		% Structure level
{0mm}	% Indention
{1ex plus 1ex minus 0.2ex}				% Pre-Margin
{0.1ex plus 0.1ex minus 0.1ex}			% Post-Margin
{\chapterheadfont\normalsize}	% Style
}

\renewcommand{\autodot}{}

%% --- End of captions style ---



% %% ---------------------------------
% %% |   Style of chapter captions   |
% %% ---------------------------------
\newlength{\chapnolen}
\newlength{\chapparlen}
\newsavebox{\chapno}
\renewcommand{\@makechapterhead}[1]{
  %\vspace*{0.2\textheight}
  \vskip 20\p@
  {\parindent \z@ \raggedright \normalfont
    \ifnum \c@secnumdepth >\m@ne
      \if@mainmatter
        \savebox{\chapno}{\chapterheadfont\huge \thechapter.}
        \settowidth{\chapnolen}{\usebox{\chapno}}
        \parbox[t]{\chapnolen}{\usebox{\chapno}}\nobreak\leavevmode
      \fi
    \fi
    \interlinepenalty\@MM
    \setlength{\chapparlen}{\textwidth}
    \addtolength{\chapparlen}{-1.0\chapnolen}
    \addtolength{\chapparlen}{-2ex}
    \leavevmode\nobreak
    \parbox[t]{\chapparlen}{\raggedright\chapterheadfont\huge #1\par\nobreak}
    \vskip 10\p@
  }}

\renewcommand{\@makeschapterhead}[1]{
  %\vspace*{50\p@}
  {\parindent \z@ \raggedright
    \normalfont
    \interlinepenalty\@M
    \chapterheadfont \huge  #1\par\nobreak
    \vskip 40\p@
  }
}
%% --- End of chapter captions style ---



%% ---------------------------------
%% |  Style of content directory   |
%% ---------------------------------
\let\oldtableofcontents\tableofcontents
\renewcommand{\tableofcontents}{{\pdfbookmark{\contentsname}{\contentsname}\chapterheadfont\oldtableofcontents}}
\let\@olddottedtocline\@dottedtocline
\renewcommand{\@dottedtocline}[5]{\@olddottedtocline{#1}{#2}{#3}{#4}{\chapterheadfont #5}}
%% --- End of content directory style ---


%% ----------------------------------
%% |  Style of appendix numbering   |
%% ----------------------------------
 \renewcommand\appendix{\par 
   \setcounter{section}{0}% 
   \setcounter{subsection}{0}% 
   \setcounter{figure}{0}%
   \renewcommand\thesection{\Alph{section}}% 
   \renewcommand\thefigure{\Alph{section}.\arabic{figure}} 
   \renewcommand\thetable{\Alph{section}.\arabic{table}}}
%% --- End of appenix numbering style ---


%% **** END OF CLASS ****
