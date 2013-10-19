%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% File:     aghdpl.cls           (LaTeX Document class option "aghdpl")
%          
% Author:  Marcin Szpyrka     (mszpyrka@agh.edu.pl)
%          Grzegorz J. Nalepa (gjn@agh.edu.pl)
%          AGH University of Science and Technology, Kraków, POLAND
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\message{*** [aghdpl.cls] ---  (MSz, GJN)  v0.22 <05.04.2011>  ***}       

\NeedsTeXFormat{LaTeX2e} % 
\ProvidesClass{aghdpl} 
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{report}} 
\ProcessOptions\LoadClass[a4paper,oneside]{report} 

\RequirePackage{graphicx}
\RequirePackage{geometry}
\RequirePackage[usenames]{color}
\RequirePackage{fancyhdr}
\RequirePackage{url}
\RequirePackage{titlesec}

\geometry{lmargin=30mm, rmargin=20mm, tmargin=25mm, bmargin=25mm, foot=10mm, head=10mm}
\definecolor{Green}{rgb}{0.1,0.5,0.1}

\def\shorttitlePL#1   {\gdef\@shorttitlePL{#1}}
\def\shorttitleEN#1   {\gdef\@shorttitleEN{#1}}
\def\shortauthor#1    {\gdef\@shortauthor{#1}}
\def\titlePL#1        {\gdef\@titlePL{#1}}
\def\titleEN#1        {\gdef\@titleEN{#1}}
\def\facultyEN#1      {\gdef\@facultyEN{#1}}
\def\facultyPL#1      {\gdef\@facultyPL{#1}}
\def\thesistypePL#1   {\gdef\@thesistypePL{#1}}
\def\thesistypeEN#1   {\gdef\@thesistypeEN{#1}}
\def\supervisorPL#1   {\gdef\@supervisorPL{#1}}
\def\supervisorEN#1   {\gdef\@supervisorEN{#1}}
\def\acknowledgements#1   {\gdef\@acknowledgements{#1}}
\def\departmentPL#1   {\gdef\@departmentPL{#1}}
\def\departmentEN#1   {\gdef\@departmentEN{#1}}

% \thesisheaders
% 
% \pagestyle{fancy}

%\bibliographystyle{abbrv}
\linespread{1.3}
\renewcommand{\labelitemi}{--}

%------------------------------------------------------------------------------

\newcommand{\titlepages}{%

\newpage \titlepage 

\begin{center}

{\sffamily{\Large{\bfseries{\textsc Akademia Górniczo-Hutnicza\\[2mm]
im. Stanisława Staszica w Krakowie}}}

\vspace*{1mm}\rule{\textwidth}{1mm}\vspace*{1mm}

{\large \@facultyPL}}\\\vspace*{2mm}
{\large\textsc{\@departmentPL}}\vspace*{1cm}

\includegraphics{img/agh}
\vspace*{1cm}

{\huge\scshape \@thesistypePL}\\\vspace*{2cm}

{\LARGE\scshape \@author}\\\vspace*{2cm}

{\LARGE{\bfseries\scshape \@titlePL}}\\\vspace*{3cm}

\begin{flushright}
\begin{minipage}[!h]{6cm} 
\large{\scshape Promotor:}\\ \@supervisorPL
\end{minipage}
\end{flushright}

\vfill{\Large Kraków \@date}

\end{center}

\clearpage \titlepage \vspace*{15cm} \vfill

\begin{flushright}
\begin{minipage}[!h]{12cm}
\mbox{\large{\scshape \textbf{OŚWIADCZENIE AUTORA PRACY}}}\\[3mm] 
{\scshape Oświadczam, świadomy odpowiedzialności karnej za poświadczenie nieprawdy, że niniejszą pracę dyplomową wykonałem osobiście i samodzielnie, i nie korzystałem ze żródeł innych niż wymienione w pracy.}\\
\end{minipage}

\vspace{2cm}

\makebox[6cm][s]{\dotfill}\par
\makebox[6cm][c]{\small PODPIS}

\end{flushright}

\clearpage \titlepage

\begin{center}

{\sffamily{\Large{\bfseries{\textsc AGH\\[2mm]
University of Science and Technology in Krakow}}}

\vspace*{1mm}\rule{\textwidth}{1mm}\vspace*{1mm}

{\large \@facultyEN}}\\\vspace*{2mm}
{\large\textsc{\@departmentEN}}\vspace*{1cm}

\includegraphics{img/agh}
\vspace*{1cm}

{\huge\scshape \@thesistypeEN}\\\vspace*{2cm}

{\LARGE\scshape \@author}\\\vspace*{2cm}

{\LARGE{\bfseries\scshape \@titleEN}}\\\vspace*{3cm}

\begin{flushright}
\begin{minipage}[!h]{6cm} 
\large{\scshape Supervisor:}\\ \@supervisorEN
\end{minipage}
\end{flushright}

\vfill{\Large Krakow \@date}

\end{center}

\clearpage \titlepage

\vspace*{15cm} \vfill
\begin{flushright} 
\begin{minipage}[!h]{8cm}
{\Large \@acknowledgements}
\end{minipage}
\end{flushright}

\clearpage

\setcounter{page}{5}

}

\def\thesisheaders{
\fancyfoot[L]{\small \@shortauthor\quad\textit{\@shorttitlePL}}
}

\DeclareOption{en}{
\def\thesisheaders{
\fancyfoot[L]{\small \@shortauthor\quad\textit{\@shorttitleEN}}
}
}

\ProcessOptions

\pagestyle{fancy}
\renewcommand{\chaptermark}[1]{\markboth{\thechapter.\ #1}{}}
\renewcommand{\sectionmark}[1]{\markright{\thesection.\ #1}}
\renewcommand{\headrulewidth}{0.5pt}
\renewcommand{\footrulewidth}{0.5pt}
\fancyhf{}
\fancyhead{}
\fancyhead[L]{\slshape{\small \rightmark}}
\fancyhead[R]{\bfseries \thepage}

\thesisheaders

\frenchspacing
\sloppy 
\widowpenalty     9999 
\clubpenalty      9999 
\flushbottom

%---------------------------------------------------------------------------
% Ustawienia parametrów dla tytułów rozdziałów, podrozdziałów, itd.
%---------------------------------------------------------------------------


\titleformat{\chapter}[block]
{\bfseries\LARGE}{\filright \LARGE\thechapter. }{0ex}{}
%odstępy: lewy, góra, dół
\titlespacing{\chapter}{0pt}{17mm}{19mm}
\titleformat{\section}[block]
{\bfseries\Large}{\filright \Large\thesection. }{0ex}{}
\titlespacing{\section}{7mm}{8mm plus 0mm minus 1mm}{4mm plus 0mm minus 1mm}
\titleformat{\subsection}[block]
{\bfseries\large}{\filright \large\thesubsection. }{0ex}{}
\titlespacing{\subsection}{7mm}{6mm}{2.5mm}
\titleformat{\subsubsection}[block]
{\bfseries\normalsize}{\filright \normalsize\thesubsubsection. }{0ex}{}
\titlespacing{\subsubsection}{7mm}{3mm}{1.5mm}

%---------------------------------------------------------------------------
% Ustawienia parametrów generowania spisu treści i spisu rysunków
%---------------------------------------------------------------------------

%\renewcommand{\cfttoctitlefont}{\bfseries\Large}
%\renewcommand{\cftbeforetoctitleskip}{20mm}
%\renewcommand{\cftaftertoctitleskip}{19mm}
%\renewcommand{\cftchapleader}{\cftdotfill{\cftdot}}
%\renewcommand{\cftsecleader}{\cftdotfill{\cftdot}}
%\renewcommand{\cftsubsecleader}{\cftdotfill{\cftdot}}
%\renewcommand{\cftchapaftersnum}{.}
%\renewcommand{\cftsecaftersnum}{.}
%\renewcommand{\cftsubsecaftersnum}{.}
%\setlength{\cftparskip}{2pt}
%\setlength{\cftbeforechapskip}{0mm}
%\renewcommand{\cftchappagefont}{\normalsize}
