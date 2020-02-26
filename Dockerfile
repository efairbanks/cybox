FROM ubuntu

MAINTAINER Eris Fairbanks <ericpfairbanks@gmail.com>

# Install dependencies and audio tools
RUN apt-get update

# Install jackd by itself first without extras since installing alongside other tools seems to cause problems
RUN apt-get -y install jackd

# Install pretty much everything we need here
RUN DEBIAN_FRONTEND='noninteractive' apt-get -y install build-essential xvfb git yasm supervisor libsndfile1-dev libsamplerate0-dev liblo-dev libasound2-dev wget ghc emacs-nox haskell-mode zlib1g-dev xz-utils htop screen openssh-server curl sudo

# Install jack libs last
RUN apt-get -y install libjack-jackd2-dev htop

# Build & Install libmp3lame
WORKDIR /repos
RUN git clone https://github.com/rbrito/lame.git
WORKDIR lame
RUN ./configure --prefix=/usr
RUN make install
WORKDIR /repos
RUN rm -fr lame

# Build & Install ffmpeg, ffserver
WORKDIR /repos
RUN git clone https://github.com/efairbanks/FFmpeg.git ffmpeg
WORKDIR ffmpeg
RUN ./configure --enable-indev=jack --enable-libmp3lame --enable-nonfree --prefix=/usr
RUN make install
WORKDIR /repos
RUN rm -fr ffmpeg

# Initialize and configure sshd
RUN mkdir /var/run/sshd
RUN echo 'root:algorave' | chpasswd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

# Expose sshd service
EXPOSE 22

# Expose ffserver streaming service
EXPOSE 8090

# Pull Tidal Emacs binding
WORKDIR /repos
RUN git clone https://github.com/efairbanks/cybin.git

ENV HOME /root
WORKDIR /root

RUN ln -s /repos /root/repos
RUN ln -s /work /root/work

# Build and install Cybin
WORKDIR /repos/cybin
RUN apt-get -y install luajit libluajit-5.1-2 libluajit-5.1-dev
RUN ./LINUX_BUILD.SH
RUN ln -s /repos/cybin/cybin /usr/bin/cybin

# Install default configurations
COPY configs/emacsrc /root/.emacs
COPY configs/screenrc /root/.screenrc
COPY configs/ffserver.conf /root/ffserver.conf

RUN echo "os.execute('jack_connect cybin:audio-out_1 ffmpeg:input_1')" >> /root/hello.cybin
RUN echo "os.execute('jack_connect cybin:audio-out_2 ffmpeg:input_2')" >> /root/hello.cybin
RUN echo "function __process() return math.random(),math.random() end" >> /root/hello.cybin

RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# Install Tidebox supervisord config
COPY configs/cybox.ini /etc/supervisor/conf.d/cybox.conf

# set root shell to screen
RUN echo "/usr/bin/screen" >> /etc/shells
RUN usermod -s /usr/bin/screen root

CMD ["/usr/bin/supervisord"]
