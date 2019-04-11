# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Clever::Client do
  include_context 'api responses'

  it 'is configurable' do
    expect(client).to be_a(Clever::Client)
    expect(client.app_id).to eq(app_id)
    expect(client.vendor_key).to eq(vendor_key)
    expect(client.vendor_secret).to eq(vendor_secret)
  end

  it 'has proper defaults' do
    client = Clever::Client.new
    expect(client.api_url).to eq(Clever::API_URL)
    expect(client.tokens_endpoint).to eq(Clever::TOKENS_ENDPOINT)
  end

  describe 'authentication' do
    let(:mock_response) { Clever::Response.new(stub(body: tokens_body, status: status)) }
    before { client.connection.expects(:execute).with(Clever::TOKENS_ENDPOINT).returns(mock_response) }

    context 'successful authentication' do
      it 'sets app_token' do
        client.connection.expects(:set_token).with(app_token)
        client.authenticate
        expect(client.app_token).to eq(app_token)
      end
    end

    context 'connection error' do
      let(:tokens_body) { nil }
      let(:status) { 401 }
      it 'raises error' do
        expect { client.authenticate }.to raise_error(Clever::ConnectionError)
      end
    end

    context 'district not found' do
      let(:tokens_body) { { 'data' => [] } }
      it 'raises error' do
        expect { client.authenticate }.to raise_error(Clever::DistrictNotFound)
      end
    end
  end

  describe 'tokens' do
    before { client.connection.expects(:execute).with(Clever::TOKENS_ENDPOINT).returns(mock_response) }
    let(:response) { client.tokens }

    context 'unsuccessful response' do
      let(:mock_response) { Clever::Response.new(stub(body: nil, status: 401)) }

      it 'returns a failed response' do
        expect(response.success?).to eq(false)
        expect(response.status).to eq(401)
      end
    end

    context 'successful response' do
      let(:raw_body) do
        {
          'data' => [{
            'id' => '58939ac0a206f40316fe8a1c',
            'created' => '2017-02-02T20:46:56.435Z',
            'owner' => { 'type' => 'district', 'id' => '5800e1c5e16c4230146fce0' },
            'access_token' => '0ed35a0de3005aa1c77df310ac0375a6158881c4',
            'scopes' => ['read:district_admins']
          }]
        }
      end
      let(:mock_response) { Clever::Response.new(stub(body: raw_body, status: 200)) }

      it 'returns a response with the body mapped' do
        expect(response.success?).to eq(true)
        expect(response.status).to eq(200)
        expect(response.raw_body).to eq(raw_body)
        expect(response.body.size).to eq(raw_body['data'].length)
      end
    end
  end

  describe 'district data requests' do
    before do
      client.connection.expects(:execute).with(Clever::TOKENS_ENDPOINT).returns(tokens_response)
      client.connection.expects(:set_token).with(app_token)
    end

    describe 'students' do
      before do
        client.connection.expects(:execute)
          .with(Clever::STUDENTS_ENDPOINT, :get, limit: Clever::PAGE_LIMIT)
          .returns(students_response)
      end

      context 'without uids passed in' do
        it 'authenticates and returns students' do
          response = client.students
          expect(client.app_token).to eq(app_token)

          expect(response.length).to eq(3)

          first_student  = response[0]
          second_student = response[1]
          third_student = response[2]

          expect(first_student.class).to eq(Clever::Types::Student)
          expect(first_student.uid).to eq(student_1['data']['id'])
          expect(first_student.first_name).to eq(student_1['data']['name']['first'])
          expect(first_student.last_name).to eq(student_1['data']['name']['last'])
          expect(first_student.username).to eq(student_1['data']['sis_id'])
          expect(first_student.provider).to eq('clever')

          expect(second_student.class).to eq(Clever::Types::Student)
          expect(second_student.uid).to eq(student_2['data']['id'])
          expect(second_student.first_name).to eq(student_2['data']['name']['first'])
          expect(second_student.last_name).to eq(student_2['data']['name']['last'])
          expect(second_student.username).to eq(student_2['data']['email'])
          expect(second_student.provider).to eq('clever')

          expect(third_student.class).to eq(Clever::Types::Student)
          expect(third_student.uid).to eq(student_3['data']['id'])
          expect(third_student.first_name).to eq(student_3['data']['name']['first'])
          expect(third_student.last_name).to eq(student_3['data']['name']['last'])
          expect(third_student.username).to eq(student_3['data']['credentials']['district_username'])
          expect(third_student.provider).to eq('clever')
        end
      end

      context 'with uids passed in' do
        it 'authenticates and returns students whose uids have been passed in' do
          response = client.students(student_1['data']['id'])

          expect(response.length).to eq(1)

          student = response[0]

          expect(student.class).to eq(Clever::Types::Student)
          expect(student.uid).to eq(student_1['data']['id'])
          expect(student.first_name).to eq(student_1['data']['name']['first'])
          expect(student.last_name).to eq(student_1['data']['name']['last'])
          expect(student.username).to eq(student_1['data']['sis_id'])
          expect(student.provider).to eq('clever')
        end
      end

      context 'with username_source' do
        context 'district_username' do
          let(:username_source) { 'district_username' }
          it 'returns the proper usernames' do
            response = client.students

            expect(response.length).to eq(3)

            first_student  = response[0]
            second_student = response[1]
            third_student  = response[2]

            expect(first_student.username).to eq(student_1['data']['sis_id'])
            expect(second_student.username).to eq(student_2['data']['email'])
            expect(third_student.username).to eq(student_3['data']['credentials']['district_username'])
          end
        end

        context 'email' do
          let(:username_source) { 'email' }
          it 'returns the proper usernames' do
            response = client.students

            expect(response.length).to eq(3)

            first_student  = response[0]
            second_student = response[1]
            third_student  = response[2]

            expect(first_student.username).to eq(student_1['data']['sis_id'])
            expect(second_student.username).to eq(student_2['data']['email'])
            expect(third_student.username).to eq(student_3['data']['email'])
          end
        end

        context 'sis_id' do
          let(:username_source) { 'sis_id' }
          it 'returns the proper usernames' do
            response = client.students

            expect(response.length).to eq(3)

            first_student  = response[0]
            second_student = response[1]
            third_student  = response[2]

            expect(first_student.username).to eq(student_1['data']['sis_id'])
            expect(second_student.username).to eq(student_2['data']['sis_id'])
            expect(third_student.username).to eq(student_3['data']['credentials']['district_username'])
          end
        end
      end
    end

    describe 'teachers' do
      before do
        client.connection.expects(:execute)
          .with(Clever::TEACHERS_ENDPOINT, :get, limit: Clever::PAGE_LIMIT)
          .returns(teachers_response)
      end

      context 'without uids passed in' do
        it 'authenticates and returns teachers' do
          response = client.teachers
          expect(client.app_token).to eq(app_token)

          expect(response.length).to eq(2)

          first_teacher  = response[0]
          second_teacher = response[1]

          expect(first_teacher.class).to eq(Clever::Types::Teacher)
          expect(first_teacher.uid).to eq(teacher_1['data']['id'])
          expect(first_teacher.email).to eq(teacher_1['data']['email'])
          expect(first_teacher.first_name).to eq(teacher_1['data']['name']['first'])
          expect(first_teacher.last_name).to eq(teacher_1['data']['name']['last'])
          expect(first_teacher.provider).to eq('clever')

          expect(second_teacher.class).to eq(Clever::Types::Teacher)
          expect(second_teacher.uid).to eq(teacher_2['data']['id'])
          expect(second_teacher.email).to eq(teacher_2['data']['email'])
          expect(second_teacher.first_name).to eq(teacher_2['data']['name']['first'])
          expect(second_teacher.last_name).to eq(teacher_2['data']['name']['last'])
          expect(second_teacher.provider).to eq('clever')
        end
      end

      context 'with uids passed in' do
        it 'authenticates and returns students whose uids have been passed in' do
          response = client.teachers(teacher_1['data']['id'])
          expect(client.app_token).to eq(app_token)

          expect(response.length).to eq(1)

          teacher = response[0]

          expect(teacher.class).to eq(Clever::Types::Teacher)
          expect(teacher.uid).to eq(teacher_1['data']['id'])
          expect(teacher.email).to eq(teacher_1['data']['email'])
          expect(teacher.first_name).to eq(teacher_1['data']['name']['first'])
          expect(teacher.last_name).to eq(teacher_1['data']['name']['last'])
          expect(teacher.provider).to eq('clever')
        end
      end

    end

    describe 'courses' do
      before do
        client.connection.expects(:execute)
          .with(Clever::COURSES_ENDPOINT, :get, limit: Clever::PAGE_LIMIT)
          .returns(courses_response)
      end

      it 'authenticates and returns courses' do
        response = client.courses
        expect(client.app_token).to eq(app_token)

        first_course  = response[0]
        second_course = response[1]

        expect(first_course.class).to eq(Clever::Types::Course)
        expect(first_course.uid).to eq(course_1['data']['id'])
        expect(first_course.district).to eq(course_1['data']['district'])
        expect(first_course.name).to eq(course_1['data']['name'])
        expect(first_course.number).to eq(course_1['data']['number'])

        expect(second_course.class).to eq(Clever::Types::Course)
        expect(second_course.uid).to eq(course_2['data']['id'])
        expect(second_course.district).to eq(course_2['data']['district'])
        expect(second_course.name).to eq(course_2['data']['name'])
        expect(second_course.number).to eq(course_2['data']['number'])
      end
    end

    describe 'sections' do
      before do
        client.connection.expects(:execute)
          .with(Clever::SECTIONS_ENDPOINT, :get, limit: Clever::PAGE_LIMIT)
          .returns(sections_response)
      end

      it 'authenticates and returns teachers' do
        response = client.sections
        expect(client.app_token).to eq(app_token)

        first_section  = response[0]
        second_section = response[1]

        expect(first_section.class).to eq(Clever::Types::Section)
        expect(first_section.uid).to eq(section_1['data']['id'])
        expect(first_section.name).to eq(section_1['data']['name'])
        expect(first_section.grades).to eq(section_1['data']['grade'])
        expect(first_section.period).to eq(section_1['data']['period'])
        expect(first_section.course).to eq(section_1['data']['course'])
        expect(first_section.teachers).to eq(section_1['data']['teachers'])
        expect(first_section.students).to eq(section_1['data']['students'])
        expect(first_section.provider).to eq('clever')

        expect(second_section.class).to eq(Clever::Types::Section)
        expect(second_section.uid).to eq(section_2['data']['id'])
        expect(second_section.name).to eq(section_2['data']['name'])
        expect(second_section.grades).to eq(section_2['data']['grade'])
        expect(second_section.period).to eq(section_2['data']['period'])
        expect(second_section.course).to eq(section_2['data']['course'])
        expect(second_section.teachers).to eq(section_2['data']['teachers'])
        expect(second_section.students).to eq(section_2['data']['students'])
        expect(second_section.provider).to eq('clever')
      end
    end

    describe 'classrooms' do
      before do
        client.connection.expects(:execute)
          .with(Clever::COURSES_ENDPOINT, :get, limit: Clever::PAGE_LIMIT)
          .returns(courses_response)
        client.connection.expects(:execute)
          .with(Clever::SECTIONS_ENDPOINT, :get, limit: Clever::PAGE_LIMIT)
          .returns(sections_response)
      end

      it 'authenticates and returns classrooms with properly mapped course numbers' do
        response = client.classrooms
        expect(client.app_token).to eq(app_token)

        first_classroom = response[0]
        second_classroom = response[1]

        expect(first_classroom.class).to eq(Clever::Types::Classroom)
        expect(first_classroom.uid).to eq(section_1['data']['id'])
        expect(first_classroom.name).to eq(section_1['data']['name'])
        expect(first_classroom.period).to eq(section_1['data']['period'])
        expect(first_classroom.course_number).to eq(course_1['data']['number'])
        expect(first_classroom.grades).to eq(section_1['data']['grade'])
        expect(first_classroom.provider).to eq('clever')

        expect(second_classroom.class).to eq(Clever::Types::Classroom)
        expect(second_classroom.uid).to eq(section_2['data']['id'])
        expect(second_classroom.name).to eq(section_2['data']['name'])
        expect(second_classroom.period).to eq(section_2['data']['period'])
        expect(second_classroom.course_number).to eq(nil)
        expect(second_classroom.grades).to eq(section_2['data']['grade'])
        expect(second_classroom.provider).to eq('clever')
      end
    end

    describe 'enrollments' do
      before do
        client.connection.expects(:execute)
          .with(Clever::SECTIONS_ENDPOINT, :get, limit: Clever::PAGE_LIMIT)
          .returns(sections_response)
      end

      context 'without classroom_uids passed in' do
        it 'authenticates and returns enrollments for primary teachers and students' do
          response = client.enrollments
          expect(client.app_token).to eq(app_token)

          student_enrollments = response[:student].each_with_object({}) do |enrollment, enrollments|
            enrollments[enrollment.classroom_uid] ||= []
            enrollments[enrollment.classroom_uid] << enrollment.user_uid
          end

          teacher_enrollments = response[:teacher].each_with_object({}) do |enrollment, enrollments|
            enrollments[enrollment.classroom_uid] ||= []
            enrollments[enrollment.classroom_uid] << enrollment.user_uid
          end

          expect(student_enrollments['5']).to eq(%w(6 7 8))
          expect(student_enrollments['20']).to eq(%w(1 2 3))

          expect(teacher_enrollments['5']).to eq(%w(5))
          expect(teacher_enrollments['20']).to eq(['6'])
        end
      end

      context 'with classroom_uids passed in' do
        it 'authenticates and returns enrollments for sections in classroom_uids' do
          response = client.enrollments([section_1['data']['id']])
          expect(client.app_token).to eq(app_token)

          student_enrollments = response[:student].each_with_object({}) do |enrollment, enrollments|
            enrollments[enrollment.classroom_uid] ||= []
            enrollments[enrollment.classroom_uid] << enrollment.user_uid
          end

          teacher_enrollments = response[:teacher].each_with_object({}) do |enrollment, enrollments|
            enrollments[enrollment.classroom_uid] ||= []
            enrollments[enrollment.classroom_uid] << enrollment.user_uid
          end

          expect(student_enrollments['5']).to eq(%w(6 7 8))
          expect(teacher_enrollments['5']).to eq(%w(5))

          expect(student_enrollments['20']).to be_nil
          expect(teacher_enrollments['20']).to be_nil
        end
      end

      context 'with shared classes flag on' do
        it 'authenticates and returns enrollments for all teachers and students' do
          client.shared_classes = true

          response = client.enrollments
          expect(client.app_token).to eq(app_token)

          student_enrollments = response[:student].each_with_object({}) do |enrollment, enrollments|
            enrollments[enrollment.classroom_uid] ||= []
            enrollments[enrollment.classroom_uid] << enrollment.user_uid
          end

          teacher_enrollments = response[:teacher].each_with_object({}) do |enrollment, enrollments|
            enrollments[enrollment.classroom_uid] ||= []
            enrollments[enrollment.classroom_uid] << enrollment.user_uid
          end

          expect(student_enrollments['5']).to eq(%w(6 7 8))
          expect(student_enrollments['20']).to eq(%w(1 2 3))

          expect(teacher_enrollments['5']).to eq(%w(5 2))
          expect(teacher_enrollments['20']).to eq(['6'])
        end
      end
    end
  end

  describe 'types .to_h' do
    context 'teacher' do
      it 'serializes the expected fields' do
        teacher = Clever::Types::Teacher.new(teacher_1)
        expect(teacher.to_h).to eq(
          uid: teacher_1['data']['id'],
          email: teacher_1['data']['email'],
          first_name: teacher_1['data']['name']['first'],
          last_name: teacher_1['data']['name']['last'],
          provider: 'clever'
        )
      end
    end

    context 'student' do
      it 'serializes the expected fields' do
        student = Clever::Types::Student.new(student_1)
        expect(student.to_h).to eq(
          uid: student_1['data']['id'],
          first_name: student_1['data']['name']['first'],
          last_name: student_1['data']['name']['last'],
          username: student_1['data']['sis_id'],
          provider: 'clever'
        )
      end
    end
  end
end
