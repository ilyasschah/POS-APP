using Api.Domain;
using Api.Helpers;
using Api.Models;
using Api.Repository;
using Microsoft.EntityFrameworkCore;

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

            if (request.Status == 5 && booking.TableIds.Count > 0)
            {
                foreach (var tableId in booking.TableIds)
                {
                    var table = await _repository._db.FloorPlanTables
                        .FirstOrDefaultAsync(t => t.Id == tableId && t.CompanyId == companyId);
                    if (table != null)
                    {
                        table.UpdateStatus(0);
                        _repository._db.FloorPlanTables.Update(table);
                    }
                }
            }

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
