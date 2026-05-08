using Api.Domain;
using Api.Helpers;
using Api.Models;
using Api.Repository;

namespace Api.Services
{
    public class BookingService(BookingRepository bookingRepository)
    {
        private readonly BookingRepository _repository = bookingRepository;

        public async Task<BookingDto> CreateAsync(CreateBookingRequest request, int companyId)
        {
            var booking = Booking.Create(
                companyId,
                request.ReservationName,
                request.StartTime,
                request.EndTime,
                request.GuestCount,
                request.CustomerId,
                request.TableIds,
                request.Note,
                request.UserId
            );
            await _repository.AddAsync(booking);
            return MapperBooking.MapToDto(booking);
        }

        public async Task<bool> UpdateStatusAsync(UpdateBookingStatusRequest request, int companyId)
        {
            var booking = await _repository.GetByIdAsync(request.BookingId, companyId);
            if (booking == null) return false;

            booking.UpdateStatus(request.Status, request.DocumentId);
            return await _repository.UpdateAsync(booking);
        }

        public async Task<bool> UpdateResourceAsync(UpdateBookingResourceRequest request, int companyId)
        {
            var booking = await _repository.GetByIdAsync(request.BookingId, companyId);
            if (booking == null) return false;

            booking.UpdateResource(request.UserId, request.TableIds);
            return await _repository.UpdateAsync(booking);
        }

        public async Task<bool> UpdateAsync(UpdateBookingRequest request, int companyId)
        {
            var booking = await _repository.GetByIdAsync(request.BookingId, companyId);
            if (booking == null) return false;

            booking.Update(
                request.ReservationName,
                request.StartTime,
                request.EndTime,
                request.GuestCount,
                request.UserId,
                request.TableIds,
                request.Note,
                request.CustomerId
            );
            return await _repository.UpdateAsync(booking);
        }

        public async Task<bool> DeleteAsync(int id, int companyId)
        {
            var booking = await _repository.GetByIdAsync(id, companyId);
            if (booking == null) return false;
            return await _repository.DeleteAsync(booking);
        }
    }
}
