using MediatR;
using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;
using System.Threading;
using System.Threading.Tasks;

namespace Documents.Api.Queries.PaymentTypeQuery
{
    public class GetPaymentTypeByIdQuery : IRequest<PaymentTypeDto?>
    {
        public int Id { get; set; }

        public class GetPaymentTypeByIdQueryHandler : IRequestHandler<GetPaymentTypeByIdQuery, PaymentTypeDto?>
        {
            private readonly PaymentTypeRepository _repository;

            public GetPaymentTypeByIdQueryHandler(PaymentTypeRepository repository)
            {
                _repository = repository;
            }

            public async Task<PaymentTypeDto?> Handle(GetPaymentTypeByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByIdAsync(request.Id);
                return entity == null ? null : MapperPaymentType.MapToPaymentTypeDto(entity);
            }
        }
    }
}