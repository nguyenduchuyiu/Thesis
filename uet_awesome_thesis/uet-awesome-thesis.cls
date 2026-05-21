% -------------------------------------------------------------------
%  @LaTeX-class-file{
%     filename        = "hust-thesis.cls",
%     version         = "0.0.1",
%     date            = "2021",
%     codetable       = "ISO/ASCII",
%     keywords        = "LaTeX, hust-thesis",
%     supported       = "send email to ngocjr7@gmail.com",
%     docstring       = "A thesis class for a HUST dissertation. This is an adaptation based on Harvard's template."
% --------------------------------------------------------------------

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{uet-awesome-thesis}[2021/12/28 University of Engineering and Technology Thesis Class]

\newcommand{\mylanguage}{en}

\DeclareOption{en}{\renewcommand{\mylanguage}{en}}
\DeclareOption{vi}{\renewcommand{\mylanguage}{vi}}
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{book}}
\ProcessOptions\relax
\LoadClass[oneside]{book}
\usepackage{scrextend}
\changefontsizes{13pt}

% Required packages
\RequirePackage{graphicx}
\RequirePackage{hyperref}
\RequirePackage[toc]{glossaries}
\RequirePackage{glossary-mcols}
\RequirePackage{here}
\RequirePackage[toc]{appendix}

\RequirePackage{amssymb}
\RequirePackage{amsmath}
\RequirePackage{mathtools}
\RequirePackage{mathspec} %loads fontspec as well

\RequirePackage[numbers, comma, sort&compress]{natbib}
\RequirePackage[small, md, sc]{titlesec}
\RequirePackage[tight,nice]{units}
\RequirePackage{verbatim}
\RequirePackage[palatino]{quotchap}
\RequirePackage{ragged2e}
% colors
\RequirePackage{color}
\definecolor{Crimson}{rgb}{0.6471, 0.1098, 0.1882}

\hypersetup{
	linktocpage,
    colorlinks,
    citecolor=black,
    filecolor=black,
    linkcolor=black,
    urlcolor=black,
}

\RequirePackage{url}
\RequirePackage[titles]{tocloft}

\setcounter{tocdepth}{3}
\setcounter{secnumdepth}{3}

\renewcommand{\cftchapfont}{\normalsize \scshape}
\setlength{\parindent}{1cm}
\setlength{\parskip}{6pt}

\RequirePackage{pdfsync} %do pdf synchronization [andy]
\RequirePackage[
    type={CC},
    modifier={by-nc-sa},
    version={3.0},
]{doclicense}

% \usepackage[closeFloats, noSeparatorLine]{fltpage} %use the custom modified fltpage package
% \RequirePackage{afterpage} 

\synctex=1 % turn synctex on automatically to sync between pdf viewer [andy]

%   list an entire bibliography entry inline. Useful for acknowledging when my paper was previously published
\RequirePackage{bibentry} 
\nobibliography*        

% \RequirePackage{lettrine} % big letter at start of chapter
\RequirePackage[a4paper]{geometry}
\geometry{left=3cm, right=2cm, top=2.5cm, bottom=3cm}

\RequirePackage{fancyhdr} 
\pagestyle{plain} % options: empty , plain , fancy

% \RequirePackage[palatino]{quotchap} % chaper number 
% \definecolor{chaptergrey}{rgb}{0.6,0,0}

\RequirePackage{afterpage} 


\RequirePackage{titling}
\RequirePackage{setspace} 
\RequirePackage{booktabs} % for much better looking tables
\RequirePackage[labelfont={bf},justification=RaggedRight,margin=0pt, figurewithin=section, tablewithin=section]{caption}

% line alignment
\linespread{1.08333333}
\addtolength{\footnotesep}{\footnotesep}
\justifying
%\raggedright


\titleformat{\chapter}[display]
  {\Huge}
  {\chaptertitlename\ \thechapter}{20pt}{\Huge\sloppy}

\titleformat{\section}
  {\Large}
  {\thesection}{1em}{\Large}
  
\titleformat{\subsection}
  {\large}
  {\thesubsection}{1em}{\large}

\titleformat{\subsubsection}[runin]
  {\bf}
  {\thesubsection}{1em}{}

\titleformat{\paragraph}[runin]
  {\it}
  {}{1em}{}

% some definitions
\def\degreeyear#1{\gdef\@degreeyear{#1}}
\def\degreemonth#1{\gdef\@degreemonth{#1}}
\def\advisor#1{\gdef\@advisor{#1}}
\def\university#1{\gdef\@university{#1}}
\def\universitycity#1{\gdef\@universitycity{#1}}
\def\major#1{\gdef\@major{#1}}


\newcommand{\isenglish}[3][\mylanguage]{
    \ifthenelse{\equal{#1}{en}}{#2}{#3}
}

\isenglish{
    \RequirePackage[english]{babel}
}{
    \RequirePackage[vietnamese]{babel}
}

\RequirePackage{tikz}
\usetikzlibrary{calc}
\usetikzlibrary{decorations.pathmorphing}

\renewcommand{\maketitle}{ 
	\singlespacing
	\thispagestyle{empty}
% 	\vspace*{\fill} 
    % \vspace{150pt} 
    \begin{tikzpicture}[overlay,remember picture]
    \draw [line width=1.5mm]
        ($ (current page.north west) + (2.2cm,-2.2cm) $)
        rectangle
        ($ (current page.south east) + (-2.2cm,2.2cm) $);
    \draw [line width=0.5mm]
        ($ (current page.north west) + (2.4cm,-2.4cm) $)
        rectangle
        ($ (current page.south east) + (-2.4cm,2.4cm) $);
    \end{tikzpicture}
    
	\begin{center}
    \begin{large}\fontsize{12pt}{1}\selectfont \textbf{\MakeUppercase{\@university}} \end{large} \\[1cm]
    {\includegraphics[scale=0.07]{UET_logo.png} \\ [1cm]}
    {\fontsize{14pt}{1}\selectfont \textbf{\@author}}\\[2cm]
    {\fontsize{18pt}{1}\selectfont \textbf{\MakeUppercase{\@title}}}\\[4cm]
    
    {\fontsize{15pt}{1}\selectfont \textbf{\isenglish{BACHELOR THESIS}{KHÓA LUẬN TỐT NGHIỆP ĐẠI HỌC HỆ CHÍNH QUY}}}\\[0.3cm]
    {\fontsize{15pt}{1}\selectfont \textbf{\isenglish{Major}{Ngành}: \@major}}\\[3.5cm]
    
    \vspace*{\fill}
	{\fontsize{12pt}{1}\selectfont \textbf{\@universitycity, \@degreeyear}}\\
	
	\end{center} 
	\newpage
}

\newcommand{\makesidecover}{ 
	\singlespacing
	\thispagestyle{empty}
% 	\vspace*{\fill} 
    % \vspace{150pt} 
    \begin{tikzpicture}[overlay,remember picture]
    \draw [line width=1.5mm]
        ($ (current page.north west) + (2.2cm,-2.2cm) $)
        rectangle
        ($ (current page.south east) + (-2.2cm,2.2cm) $);
    \draw [line width=0.5mm]
        ($ (current page.north west) + (2.4cm,-2.4cm) $)
        rectangle
        ($ (current page.south east) + (-2.4cm,2.4cm) $);
    \end{tikzpicture}
	\begin{center}
    \begin{large}\fontsize{12pt}{1}\selectfont \textbf{\MakeUppercase{\@university}} \end{large} \\[2cm]
    {\fontsize{14pt}{1}\selectfont \textbf{\@author}}\\[2.5cm]
    {\fontsize{18pt}{1}\selectfont \textbf{\MakeUppercase{\@title}}}\\[4cm]
    
    {\fontsize{15pt}{1}\selectfont \textbf{\isenglish{BACHELOR THESIS}{KHÓA LUẬN TỐT NGHIỆP ĐẠI HỌC HỆ CHÍNH QUY}}}\\[0.3cm]
    {\fontsize{15pt}{1}\selectfont \textbf{\isenglish{Major}{Ngành}: \@major}}\\[3cm]
	
	\end{center} 
    
    {\noindent \fontsize{14pt}{1}\selectfont \textbf{\isenglish{Supervisor:}{Cán bộ hướng dẫn:}}}\\[3cm]
    {\fontsize{14pt}{1}\selectfont \textbf{\isenglish{Co-supervisor:}{Cán bộ đồng hướng dẫn:}}}\\[0.3cm]
    
    \vspace*{\fill}
    
    \begin{center}
	{\fontsize{12pt}{1}\selectfont \textbf{\@universitycity, \@degreeyear}}\\
	\end{center}
	\newpage
}

\def\authorclass#1{\gdef\@authorclass{#1}}
\def\duration#1{\gdef\@duration{#1}}
\def\statement#1{\gdef\@statement{#1}}
\def\declaration#1{\gdef\@declaration{#1}}

% You might also consider licensing your work under Creative Commons). See: http://creativecommons.org/weblog/entry/12824 for other PhD students who have released their work under creative commons.

\newcommand{\abstractpage}[2][\mylanguage]{
	\newpage
% 	\pagenumbering{roman}
% 	\setcounter{page}{3}
	\pagestyle{fancy}
	\lhead{\isenglish[#1]{Thesis advisor}{Giảng viên hướng dẫn}: \@advisor} \rhead{\@author}
	\renewcommand{\headrulewidth}{0.0pt} 
	\begin{center}
	\vspace*{1pt}
	\Large \textcolor{Crimson}{\textit{\@title}} \normalsize\\
	\vspace*{15pt}
	\bf \isenglish[#1]{Abstract}{Tóm tắt đồ án} \\ \rm
	\end{center}
	\doublespace %Harvard registrar requests that abstract is double spaced
	#2
	\doublespace %Harvard registrar requests that abstract is double spaced	
	\newpage \lhead{} \rhead{}
	\cfoot{\thepage}
	\onehalfspacing
}

\newcommand{\dedicationpage}[1]{
	\pagestyle{fancy}
	\newpage \thispagestyle{fancy} \vspace*{\fill}
	\sc \noindent #1
	\vspace*{\fill} \newpage \rm
	}

% the list of authors
\newcommand{\authorlist}[1]{
	\pagestyle{fancy}
	\newpage
	\thispagestyle{fancy} 
	\isenglish{\chapter*{Author List}}{\chapter*{Danh sách tác giả}}
	\noindent #1
	\newpage \rm
	}
	

% the acknowledgments page
\newcommand{\acknowledgments}[1]{
    \isenglish{\chapter*{Acknowledgments}}{\chapter*{Lời cảm ơn}}
    \pagestyle{fancy}
	\noindent
	\onehalfspacing
	#1
	\vspace*{\fill} 
	\newpage
}

\newcommand{\authorship}{
    \isenglish{\chapter*{Authorship}}{\chapter*{Tuyên thệ của tác giả}}
    \pagestyle{fancy}
	\noindent “I hereby declare that the work contained in this thesis is of my own and has not been previously submitted for a degree or diploma at this or any other higher education institution. To the best of my knowledge and belief, the thesis contains no materials previously published or written by another person except where due reference or acknowledgement is made.” \\ [2cm]

    \noindent Signature:………………………………………………
	\vspace*{\fill} 
	\newpage
}

\newcommand{\approval}{
    \isenglish{\chapter*{Supervisor's approval}}{\chapter*{Xác nhận của cán bộ hướng dẫn}}
    \pagestyle{fancy}
	\noindent “I hereby approve that the thesis in its current form is ready for committee examination as a requirement for the Bachelor of Computer Science degree at the University of Engineering and Technology.” \\ [2cm]

    \noindent Signature:………………………………………………
	\vspace*{\fill} 
	\newpage
}
	
% An environment for paragraph-style section
\providecommand\newthought[1]{%
   \addvspace{1.0\baselineskip plus 0.5ex minus 0.2ex}%
   \noindent\textsc{#1}}

% An environment for sign box
\newcommand{\signbox}[2]{
\begin{minipage}{0.5\linewidth}
\end{minipage}\hfill
\begin{minipage}{0.45\linewidth}
\begin{flushright}
\vbox{
    \begin{center}
	\textit{\@universitycity, \isenglish{date}{ngày} \space \space \space \isenglish{month}{tháng} \space \space \space \isenglish{year}{năm} \@degreeyear}
	\\ #1
	\\~
	\\~
	\\ \textit{#2}
	\end{center}
}
\end{flushright}
\end{minipage}
}

% \dotline and \dotfill
\def\dotfill#1{\cleaders\hbox to #1{.}\hfill}
\newcommand\dotline[2][.5em]{\leavevmode\hbox to #2{\dotfill{#1}\hfil}}

\renewenvironment{savequote}[1][10cm]{%
\begin{lrbox}{\@quotebox}
\noindent
\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lr|}
&\begin{minipage}[t]{#1}\footnotesize\quotefont
\ignorespaces
}{%
\end{minipage}
\end{tabular*}
\end{lrbox}
\global\setbox\@quotebox\copy\@quotebox
\global\let\@printcites\@iprintcites
\ignorespacesafterend}


% remove hyperlink, mostly used for citation in caption and headline
\newcommand{\nohyper}[1]{\protect\NoHyper#1\protect\endNoHyper}

\renewcommand\bibname{References}
\renewcommand\listfigurename{Listing of Figures}

% undo the wrong changes made by mathspec
\makeatletter 
\let\RequirePackage\original@RequirePackage
\let\usepackage\RequirePackage
\makeatother