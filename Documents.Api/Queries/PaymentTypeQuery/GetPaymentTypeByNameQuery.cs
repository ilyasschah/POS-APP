using Documents.Api.Helpers;
using Documents.Api.Models;
using Documents.Api.Repository;
using MediatR;

namespace Documents.Api.Queries.PaymentTypeQuery
{
    public class GetPaymentTypeByNameQuery : IRequest<PaymentTypeDto?>
    {
        public string Name { get; set; }

        public class GetPaymentTypeByNameQueryHandler : IRequestHandler<GetPaymentTypeByNameQuery, PaymentTypeDto?>
        {
            private readonly PaymentTypeRepository _repository;

            public GetPaymentTypeByNameQueryHandler(PaymentTypeRepository repository)
            {
                _repository = repository;
            }

            public async Task<PaymentTypeDto?> Handle(GetPaymentTypeByNameQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetByNameAsync(request.Name);
                return entity == null ? null : MapperPaymentType.MapToPaymentTypeDto(entity);
            }
        }
    }
}